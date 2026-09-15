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