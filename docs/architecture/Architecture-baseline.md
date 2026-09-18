+++
title = "Architecture Baseline ASCII Diagram"
domain = "architecture"
tier = 1
topics = ["apigee", "psc", "cloud-run", "architecture", "diagram"]
parent = "README.md"
children = []
related = [
    "docs/architecture/architecture.md",
    "docs/architecture/traffic-flows.md",
    "Challenge/challenge.md"
]
updated_by = "Antigravity AI"
version = "1.1"
+++

> **Parent**: [`README.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/README.md)
> **Manifest**: [`AI_MANIFEST.toml`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AI_MANIFEST.toml)
> **Full Architecture**: [`architecture.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/architecture/architecture.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Lightweight ASCII baseline diagram of the end-to-end Apigee Non-VPC-Peering + PSC architecture.
- Questions Answered: What does the high-level traffic flow look like? What are the main components?
- When to Retrieve: Quick orientation, diagram review, or orienting a new agent with minimal token budget.
- When NOT to Retrieve: When hop-by-hop detail, CIDR tables, or security controls are needed.
-->

                         INTERNET
                            |
                            v
                   +----------------+
                   | External Client|
                   +----------------+
                            |
                          HTTPS
                            |
                            v
               +---------------------------+
               | Regional External         |
               | Application Load Balancer |
               |       us-south1            |
               +-------------+-------------+
                             |
                     Cloud Armor / WAF
                             |
                             v
                    Private Service
                      Connect PSC
                             |
                             v
                +-------------------------+
                | APIGEE MANAGED RUNTIME  |
                |   Non-VPC-Peering       |
                |       us-south1          |
                +------------+------------+
                             |
                       API policies
                             |
                             v
                    Private Service
                      Connect PSC
                             |
                             v
                    PSC Endpoint /
                    Service Attachment
                             |
                             v
                +-------------------------+
                | Private Backend Layer   |
                | Internal LB / NEG       |
                +------------+------------+
                             |
                +------------+-------------+
                |                          |
                v                          v
          +-------------+          +---------------+
          | Cloud Run   |          | Hybrid Path   |
          | private     |          |               |
          +-------------+          +-------+-------+
                                           |
                                         Hub VPC
                                           |
                                       Cloud VPN
                                           |
                                           v
                                      ON-PREMISES
                                           |
                                  +--------+--------+
                                  |                 |
                                  v                 v
                           Java Application       RDBMS