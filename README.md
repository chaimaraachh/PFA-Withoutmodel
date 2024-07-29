# PFA-Withoutmodel

## Overview

This repository is part of our end-of-year project (Projet Fin d'Année - PFA) titled "Deep Reinforcement Learning for Edge Kubernetes Load Optimization." It includes various configuration files, scripts, and templates essential for the project. Note that this repository does not include the model, which is available in a separate repository.

## Project Description

In this project, we aim to optimize load distribution in Kubernetes clusters deployed at edge locations using Deep Reinforcement Learning (DRL). Our approach dynamically adjusts resource allocation in real-time to respond to fluctuating demands and network conditions. We developed a custom simulation environment to train and validate our models, achieving significant improvements in resource utilization and response time compared to traditional load balancing methods.

## Structure

- `Dockerfile.memory_simulation`: Dockerfile for memory simulation
- `app.yaml.template`: Template for application deployment configuration
- `grafana-ingress.yaml`: Grafana ingress configuration
- `k3d-config.yaml.template`: Template for k3d configuration
- `prom-values.yaml.template`: Template for Prometheus values
- `simulate_memory_usage.py`: Script to simulate memory usage
- `start.sh`: Shell script to start the application
- `static-info-dashboard.json.template`: Template for Grafana static info dashboard

## Getting Started

### Prerequisites

- Docker
- K3d
- Prometheus
- Grafana

### Installation

1. Clone the repository:
   ```bash
   git clone https://github.com/chaimaraachh/PFA-Withoutmodel.git


2. Use the start.sh script to initiate the setup:
   ```bash
    ./start.sh
