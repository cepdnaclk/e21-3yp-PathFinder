---
layout: home
permalink: index.html

repository-name: e21-3yp-PathFinder
title: PathFinder
---

# PathFinder  
### Intelligent Wearable Navigation System for the Visually Impaired

---

## Team
- E/21/141, Francisco R.D.D.K., [e21141@eng.pdn.ac.lk](mailto:e21141@eng.pdn.ac.lk)
- E/21/442, Wijenayaka D.L.P.A., [e21442@eng.pdn.ac.lk](mailto:e21442@eng.pdn.ac.lk)
- E/21/157, Gunarathne R.C., [e21157@eng.pdn.ac.lk](mailto:e21157@eng.pdn.ac.lk)
- E/21/361, Sasindu K.T., [e21361@eng.pdn.ac.lk](mailto:e21361@eng.pdn.ac.lk)

<!-- Image of the wearable chest band prototype will be added here -->

---

## Table of Contents
1. [Introduction](#introduction)
2. [Solution Architecture](#solution-architecture)
3. [Hardware and Software Designs](#hardware-and-software-designs)
4. [Testing](#testing)
5. [Detailed Budget](#detailed-budget)
6. [Conclusion](#conclusion)
7. [Links](#links)

---

## Introduction

Visually impaired individuals face significant challenges when navigating indoor corridors, crowded public spaces, and road crossings. Traditional assistive tools such as white canes provide limited information and do not support dynamic awareness of people, vehicles, or hazardous situations. PathFinder addresses this problem by introducing an intelligent wearable navigation system designed as a chest band. The system combines camera-based object detection, ultrasonic sensing, and edge computing to provide real-time audio guidance. It operates in two manually selectable modes: Pedestrian Mode, which detects and announces nearby people and obstacles, and Road Mode, which prioritizes vehicle detection for safer road crossings. An SOS feature enables users to instantly share their location with caregivers through a mobile application, improving safety and independence.

---

## Solution Architecture

The PathFinder system consists of a wearable device, a cloud backend, and a mobile application. The wearable device integrates a Raspberry Pi for vision-based processing and an ESP32 microcontroller for handling ultrasonic and button inputs, and real-time communication. The Raspberry Pi performs object detection and risk assessment, while the ESP32 manages low-level sensing and user interactions. Processed data and alerts are securely transmitted to the cloud, which synchronizes information with a mobile application used by caregivers for monitoring, notifications, and emergency response.

---

## Hardware and Software Designs

### Hardware Design
- Raspberry Pi 4 with camera module for object and vehicle detection  
- ESP32 microcontroller for sensor processing and control  
- Ultrasonic sensors for obstacle distance measurement  
- Speaker for audio feedback  
- Two physical buttons: SOS and Mode Selection  
- Rechargeable battery system  

### Software Design
- Embedded firmware on ESP32 for sensor data processing and mode control  
- Vision-based object detection on Raspberry Pi  
- Firebase-based backend for data storage and notifications  
- Flutter-based mobile application for caregivers  

---

## Testing

Testing includes unit testing of sensor readings, integration testing between ESP32 and Raspberry Pi, and functional testing of both navigation modes. Field tests are conducted in indoor corridors and near road crossings to validate detection accuracy, audio feedback clarity, and SOS reliability. Results are analyzed to improve robustness and reduce false alerts.

---

## Detailed Budget

| Item                     | Quantity | Unit Cost (LKR) | Total (LKR) |
|--------------------------|----------|-----------------|-------------|
| Raspberry Pi 4           | 1        | 30,000          | 30,000      |
| ESP32                    | 1        | 1,700           | 1,700       |
| Camera Module            | 1        | 7,900           | 7,900       |
| Ultrasonic Sensors       | 3        | 300             | 900         |
| Speaker + Buttons        | -        | 2,000           | 2,000       |
| Battery & Power Circuit  | -        | 8,000           | 8,000       |
| **Total**                |          |                 | **55,000**  |

---

## Conclusion

PathFinder demonstrates a practical and affordable wearable navigation solution for visually impaired users by combining sensor fusion, edge computing, and mobile connectivity. The system enhances situational awareness in both pedestrian environments and road crossings while providing emergency assistance through an SOS feature. Future work includes improving detection accuracy, optimizing power consumption, and exploring commercialization opportunities for real-world deployment.

---

## Links
- [Project Repository](https://github.com/cepdnaclk/{{ page.repository-name }}){:target="_blank"}
- [Project Page](https://cepdnaclk.github.io/{{ page.repository-name }}){:target="_blank"}
- [Department of Computer Engineering](http://www.ce.pdn.ac.lk/)
- [University of Peradeniya](https://eng.pdn.ac.lk/)
