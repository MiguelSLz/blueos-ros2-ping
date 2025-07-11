ARG ROS_DISTRO=humble
FROM ros:$ROS_DISTRO-ros-base

RUN echo "deb http://ports.ubuntu.com/ubuntu-ports jammy main restricted universe multiverse" > /etc/apt/sources.list && \
    echo "deb http://ports.ubuntu.com/ubuntu-ports jammy-updates main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://ports.ubuntu.com/ubuntu-ports jammy-backports main restricted universe multiverse" >> /etc/apt/sources.list && \
    echo "deb http://ports.ubuntu.com/ubuntu-ports jammy-security main restricted universe multiverse" >> /etc/apt/sources.list

RUN apt-get update \
    && apt-get install -q -y --no-install-recommends \
    git tmux nano nginx wget netcat \
    libboost-all-dev libasio-dev libgeographic-dev geographiclib-tools \
    ros-${ROS_DISTRO}-geographic-msgs \
    ros-${ROS_DISTRO}-foxglove-bridge \
    ros-${ROS_DISTRO}-image-transport \
    ros-${ROS_DISTRO}-angles \
    ros-${ROS_DISTRO}-diagnostic-updater \
    ros-${ROS_DISTRO}-eigen-stl-containers \
    ros-${ROS_DISTRO}-mavlink \
    python3-dev python3-pip python3-click python3-scipy \
    && apt-get autoremove -y \
    && apt-get clean -y \
    && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-cache-dir setuptools pip packaging -U \
    && pip3 install --no-cache-dir bluerobotics-ping

COPY ros2_ws /home/ros2_ws
WORKDIR /home/ros2_ws/src
RUN git clone https://github.com/mavlink/mavros.git -b ros2 && \
    git clone --recurse-submodules https://github.com/CentraleNantesRobotics/ping360_sonar.git -b ros2

# ----------- Changes on source code stay here! ----------- #

COPY files/imu.cpp.modificado /home/ros2_ws/src/mavros/mavros/src/plugins/imu.cpp
COPY files/apm.launch.modificado /home/ros2_ws/src/mavros/mavros/launch/apm.launch
COPY files/base.launch.py.modificado /home/ros2_ws/src/mavros_control/launch/base.launch.py
COPY files/demo.launch.py.modificado /home/ros2_ws/src/mavros_control/launch/demo.launch.py

# ----------- Changes on source code stay here! ----------- #

WORKDIR /home/ros2_ws/
RUN . "/opt/ros/${ROS_DISTRO}/setup.sh" \
    && rosdep update \
    && rosdep install --from-paths src --ignore-src -r -y \
    && python3 -m pip install --no-cache-dir -r src/mavros_control/requirements.txt \
    && colcon build --parallel-workers 1

WORKDIR /home/ros2_ws/
RUN . "/opt/ros/${ROS_DISTRO}/setup.sh" \
    && . "/home/ros2_ws/install/setup.sh" \
    && ros2 run mavros install_geographiclib_datasets.sh \
    && echo "source /ros_entrypoint.sh" >> ~/.bashrc \
    && echo "source /home/ros2_ws/install/setup.sh " >> ~/.bashrc

ENV NAVIGATION_TYPE=0 FOXGLOVE=True
ENV ROS_DOMAIN_ID=1

ADD files/install-ttyd.sh /install-ttyd.sh
RUN bash /install-ttyd.sh && rm /install-ttyd.sh
COPY files/tmux.conf /etc/tmux.conf

RUN mkdir -p /site
COPY files/register_service /site/register_service
COPY files/nginx.conf /etc/nginx/nginx.conf

ADD files/start.sh /start.sh

LABEL version="1.0.0-custom"
LABEL permissions='{\
  "NetworkMode": "host",\
  "HostConfig": {\
    "Binds": [\
      "/dev:/dev:rw",\
      "/usr/blueos/extensions/ros2/:/home/persistent_ws/:rw"\
    ],\
    "Privileged": true\
  },\
  "Env": [\
    "NAVIGATION_TYPE=0", \
    "FOXGLOVE=True" \
  ]\
}'
LABEL io.blueos.web-ui.port="80"
LABEL io.blueos.web-ui.path="/"

LABEL authors='[\
  {\
    "name": "Kalvik Jakkala",\
    "email": "itskalvik@gmail.com"\
  },\
  {\
    "name": "Miguel Soria",\
    "email": "miguel.luz@labmetro.ufsc.br"\
  }\
]'
LABEL company='{\
  "about": "",\
  "name": "VORIS / ItsKalvik",\
  "email": "projeto.voris@labmetro.ufsc.br"\
}'
LABEL readme="https://raw.githubusercontent.com/miguelslz/blueos-ros2/main/README.md"
LABEL type="other"
LABEL tags='[\
  "ros2",\
  "robot"\
]'

RUN echo "set +e" >> ~/.bashrc
ENTRYPOINT [ "/start.sh" ]
