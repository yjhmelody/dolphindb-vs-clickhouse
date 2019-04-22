version: '3'

services:
  ddbcontroller:
    image: ddb:latest
    container_name: ddbcontroller
    environment:
      - DEPLOY_MODE=controller
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - ./cfg/dolphindb.lic:/data/ddb/server/dolphindb.lic
      - ./Cluster/controller/master:/data/ddb/server/master
      - ./Cluster/controller/log:/data/ddb/server/log
      - ./cfg/controller.cfg:/data/ddb/server/config/controller.cfg
      - ./cfg/cluster.cfg:/data/ddb/server/config/cluster.cfg
      - ./cfg/cluster.nodes:/data/ddb/server/config/cluster.nodes
    ports:
      - "8888:8888"
    networks:
      dbnet:
        ipv4_address: 10.5.0.5

  ddbagent1:
    image: ddb:latest
    container_name: ddbagent1
    environment:
      - DEPLOY_MODE=agent
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - ./cfg/dolphindb.lic:/data/ddb/server/dolphindb.lic
      - ./Cluster/server1/log:/data/ddb/server/log
      - ./Cluster/server1/P1-agent:/data/ddb/server/P1-agent
      - ./Cluster/server1/P1-node1:/data/ddb/server/P1-node1
      - ./Cluster/server1/P1-node2:/data/ddb/server/P1-node2
      - ./cfg/agent1.cfg:/data/ddb/server/config/agent.cfg
    ports:
      - "8710:8710"
      - "8711:8711"
      - "8712:8712"
    networks:
      dbnet:
        ipv4_address: 10.5.0.2

  ddbagent2:
    image: ddb:latest
    container_name: ddbagent2
    environment:
      - DEPLOY_MODE=agent
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - ./cfg/dolphindb.lic:/data/ddb/server/dolphindb.lic
      - ./Cluster/server2/log:/data/ddb/server/log
      - ./Cluster/server2/P2-agent:/data/ddb/server/P2-agent
      - ./Cluster/server2/P2-node1:/data/ddb/server/P2-node1
      - ./Cluster/server2/P2-node2:/data/ddb/server/P2-node2
      - ./cfg/agent2.cfg:/data/ddb/server/config/agent.cfg
    ports:
      - "8810:8810"
      - "8811:8811"
      - "8812:8812"
    networks:
      dbnet:
        ipv4_address: 10.5.0.3

  ddbagent3:
    image: ddb:latest
    container_name: ddbagent3
    environment:
      - DEPLOY_MODE=agent
    ulimits:
      memlock:
        soft: -1
        hard: -1
      nofile:
        soft: 65536
        hard: 65536
    volumes:
      - ./cfg/dolphindb.lic:/data/ddb/server/dolphindb.lic
      - ./Cluster/server3/log:/data/ddb/server/log
      - ./Cluster/server3/P3-agent:/data/ddb/server/P3-agent
      - ./Cluster/server3/P3-node1:/data/ddb/server/P3-node1
      - ./cfg/agent3.cfg:/data/ddb/server/config/agent.cfg
    ports:
      - "8910:8910"
      - "8911:8911"
      - "8912:8912"
    networks:
      dbnet:
        ipv4_address: 10.5.0.4

networks:
  dbnet:
    driver: bridge
    ipam:
      config:
       - subnet: 10.5.0.0/16
