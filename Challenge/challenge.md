+++
title = "Rocket Code Technical Exercise Requirements"
domain = "requirements"
tier = 1
topics = ["requirements", "challenge", "exercise", "apigee", "constraints", "deliverables"]
parent = "README.md"
children = []
related = [
    "README.md",
    "AGENTS.md",
    "docs/decisions/architecture-decisions.md",
    "docs/assumptions/assumptions-risks-tradeoffs.md"
]
updated_by = "Antigravity AI"
version = "1.1"
+++

> **Parent**: [`README.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/README.md)
> **Manifest**: [`AI_MANIFEST.toml`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/AI_MANIFEST.toml)
> **Architecture Decisions**: [`architecture-decisions.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/decisions/architecture-decisions.md)
> **Assumptions**: [`assumptions-risks-tradeoffs.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/docs/assumptions/assumptions-risks-tradeoffs.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Canonical, unmodified technical exercise requirements from Rocket Code.
- Questions Answered: What are the exact deliverables? What are the hard constraints? What does the evaluator expect? What components must be included?
- When to Retrieve: Verifying compliance with exercise requirements, reviewing evaluation criteria, or orienting a new agent on the objective.
- When NOT to Retrieve: When reading the current architectural design (use docs/architecture/) or the implementation plan (use AGENTS.md).
-->

Introducción
Como parte del proceso de evaluación para la vacante de Cloud Engineer DevOps en
rocket code, te compartimos este ejercicio técnico para conocer tu capacidad de
análisis, diseño de arquitectura cloud, toma de decisiones y manejo de escenarios
con conectividad privada, seguridad e infraestructura como código.
Para realizarlo, será necesario que cuentes con acceso a un ambiente de Google
Cloud Platform (GCP), ya que el caso práctico está orientado a validar tu criterio
técnico en un contexto cloud realista.
No buscamos una solución extensa, sino una propuesta clara, viable y bien
argumentada. Si falta algún dato, puedes asumirlo y declararlo dentro de tu entrega.
Se permite el uso de documentación oficial y asistentes de IA durante la preparación;
sin embargo, la defensa oral será sin apoyo, por lo que deberás poder explicar y
sustentar cada decisión incluida en tu propuesta.
Gracias por tu tiempo y participación en este proceso.

EVALUACIÓN TÉCNICA
Ingeniero / Arquitecto Cloud
Caso práctico: exposición de APIs con runtime administrado y conectividad privada
1. El caso
Una organización necesita construir su plataforma de gestión de APIs en la nube pública, para
exponer servicios a canales propios y a terceros externos. Parte de sus sistemas seguirá operando
on-premises. El resto del contexto está en el diagrama de la página siguiente.
Lo que no está permitido
• Exponer backends directamente a internet.
• Asignar IPs de la organización al runtime administrado, o asumir que el proveedor rutea
hacia rangos privados arbitrarios del cliente.
• Resolver la transitividad agregando peerings adicionales entre VPCs.
• Traslapar rangos con el direccionamiento ya asignado en la red existente.
• Configuración manual: todo debe ser reproducible como infraestructura como código.

2. Punto de partida
El diagrama muestra lo que ya está definido y lo que tienes que resolver. La zona marcada es el
centro del ejercicio.

---

### Análisis Detallado del Esquema Técnico (`Challenge/FullView.png`)

A continuación se documenta el desglose arquitectónico y las reglas del diagrama oficial provisto por Rocket Code:

#### Reglas de Diseño y Leyenda del Esquema (Pie del Diagrama)

* **Trazo morado continuo**: *Componentes nuevos que debes diseñar* (`Proyecto de APIs · spoke nuevo`, `Punto de entrada externo · WAF`, `ZONA A DISEÑAR`, `Plataforma de apps`).
* **Trazo punteado gris**: *Fuera de tu control* (`Tenant del proveedor / Runtime administrado`, `On-premises · core de negocio`).
* **Trazo gris continuo**: *Existente* (`Hub de red · VPC central`).
* **Directriz general**: *"Diagrama de contexto. Nombres, regiones y rangos son deliberadamente genéricos: defínelos tú."* (Se define formalmente: Región `us-south1`, nombres estandarizados y rangos CIDR no traslapados).

---

#### Diagrama de Flujo y Topología de Referencia

```text
                           [ Clientes externos ]
                                     │
                                     ▼
      ┌─────────────────────────────────────────────────────────────┐       ┌ - - - - - - - - - - - - - - - ┐
      │  Proyecto de APIs · spoke nuevo (Lo diseñas tú · us-south1) │         Tenant del proveedor          
      │                                                             │       │ (Fuera de tu VPC · no spoke)  │
      │  ┌───────────────────────────────────────────────────────┐  │
      │  │ Punto de entrada externo · WAF (Cloud Armor + Reg LB) │  │       │ ┌───────────────────────────┐ │
      │  └───────────────────────────┬───────────────────────────┘  │         │    Runtime administrado   │  
      │                              ▼                              │       │ │ (Apigee Non-VPC-Peering)  │ │
      │  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐    │           │ No admite IPs organización│  
      │    VPC de APIs                                              │       │ └─────────────┬─────────────┘ │
      │  │ ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐      │─ ─ ─entrada ?─ ─ ── ─ ┘               
      │        ? ZONA A DISEÑAR                              │      │                                       │
      │  │ │                                                 │◀─ ─ ─ ─salida ?─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─┘
      │    └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘ │    │
      │  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘    │
      └──────────────┬──────────────────────────────┬───────────────┘
                     │                              │
                     ▼                              │
      ┌──────────────────────────────┐              │
      │ Plataforma de apps           │              │
      │ (Cloud Run + Serverless NEG) │              │
      └──────────────┬───────────────┘              │
                     │                              │
                     ▼                              ▼
      ┌─────────────────────────────────────────────────────────────┐
      │ Hub de red · VPC central (Existente · conectividad híbrida) │
      └──────────────────────────────┬──────────────────────────────┘
                                     │ (Cloud VPN)
                                     ▼
      ┌ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - ┐
        On-premises · core de negocio                                
      │ (Servidor Java + Base de datos relacional)                  │
        * Latencia alta en hora pico *
      └ - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - ┘
```

---

#### Desglose de Componentes y Solución Arquitectónica

##### A. Ingress: `Clientes externos` -> `Punto de entrada externo · WAF`
* **Definición**: Punto de entrada perimetral con inspección y filtrado antes de ingresar a la red interna.
* **Solución**:
  * **Regional External Application Load Balancer** en la región `us-south1`.
  * **Google Cloud Armor** (política de seguridad WAF con reglas OWASP Top 10, filtrado IP y rate limiting).

##### B. `Tenant del proveedor · Runtime administrado` (Apigee)
* **Restricciones del esquema**:
  * *"No es un spoke · fuera de tu VPC"*
  * *"No admite IPs de la organización"*
  * *"Dado: no lo puedes modificar ni meterlo al hub-and-spoke"*
* **Solución**:
  * **Modelo Non-VPC Peering de Apigee**: El runtime opera en un tenant administrado por Google. No se le asignan rangos CIDR `/22` o `/28` de la organización ni se crea VPC Peering cliente-proveedor.

##### C. El Núcleo del Reto: `? ZONA A DISEÑAR`
El esquema plantea 5 preguntas específicas en el recuadro central:

| Pregunta en el Diagrama | Desafío Técnico | Solución Arquitectónica Justificada |
| :--- | :--- | :--- |
| **1. Cómo entra el tráfico al runtime administrado?** (`entrada ?`) | Ingress hacia Apigee | **Northbound Private Service Connect (PSC)**: El Regional External Application LB reenvía el tráfico mediante un PSC NEG hacia el Service Attachment del runtime de Apigee de forma 100% privada. |
| **2. Cómo regresa el tráfico hacia los backends?** (`salida ?`) | Egress de Apigee hacia backends | **Southbound Private Service Connect (PSC)**: Las políticas y TargetServers de Apigee utilizan un **Endpoint Attachment** que apunta a un **PSC Service Attachment** publicado en la VPC de APIs del cliente. |
| **3. Qué artefactos de conectividad privada usas?** | Recursos GCP de red privada | • `google_compute_service_attachment` (PSC Service Attachment)<br>• PSC Endpoint Attachment en Apigee<br>• Serverless NEG (`google_compute_region_network_endpoint_group`)<br>• Internal Application Load Balancer para distribución privada. |
| **4. Qué subredes especiales se requieren?** | Subredes con propósitos reservados | • **Proxy-Only Subnet** (`purpose = REGIONAL_MANAGED_PROXY`): Requerida para los balanceadores de carga regionales (externo e interno).<br>• **PSC NAT Subnet** (`purpose = PRIVATE_SERVICE_CONNECT`): Requerida para que el Service Attachment traduzca las IPs de los consumidores hacia la VPC local. |
| **5. Dónde está el punto de transición a la red interna?** | Límite entre runtime externo y red corporativa | La transición ocurre en el **PSC Service Attachment en la VPC de APIs**. Desde allí, el tráfico se enruta privadamente hacia **Cloud Run** (vía Serverless NEG) o hacia el **Hub VPC** y on-premises. |
| **Restricción no negociable** | *"Sin peering transitivo · sin exponer backends a internet"* | • **Sin Peering Transitivo**: Se utiliza conectividad basada en endpoints PSC, evitando peerings transitivos no soportados entre spokes.<br>• **Cero Exposición a Internet**: El servicio Cloud Run tiene la directiva de ingress restringida a `internal-and-cloud-load-balancing`. |

##### D. `Plataforma de apps` (Proyecto nuevo)
* **Definición**: *"Proyecto nuevo · Contenedores y servicios administrados"*.
* **Solución**: **Google Cloud Run** ejecutando un microservicio contenedorizado ligero, publicado a través de un Internal Load Balancer con Serverless NEG, manteniendo aislamiento privado total.

##### E. `Hub de red · VPC central` & `On-premises · core de negocio`
* **Definición**: *"Existente · concentra la conectividad híbrida"* -> *"Servidor de aplicaciones Java · base de datos relacional · Latencia alta en hora pico"*.
* **Solución Híbrida**: **Cloud VPN** (HA VPN) conecta el Hub VPC central existente con el entorno on-premises sin requerir infraestructuras WAN sobrediseñadas.
* **Nota Crítica sobre "Latencia alta en hora pico"**:
  * El esquema destaca intencionalmente que el core on-premises sufre alta latencia en horas pico.
  * **Defensa Técnica / Entrevista Oral**: El balanceador de carga **NO** resuelve la lentitud de la base de datos on-premises. El balanceador gestiona tráfico y termina TLS perimetralmente, pero no optimiza consultas SQL.
  * **Estrategia**: Se implementa observabilidad integral (**Cloud Trace + Cloud Monitoring**) para trazar la cadena completa de latencia (`Cliente -> LB -> PSC -> Apigee -> PSC -> Backend -> VPN -> Java App -> DB`) y demostrar exactamente dónde reside el cuello de botella, recomendando caché en Apigee, pooling de conexiones o escalado del backend.

---


3. Entregables deseables
Ninguno es obligatorio. Entrega lo que consideres necesario para sustentar tu diseño: los criterios de aceptación se evalúan sobre lo que decidas entregar y sobre lo que expliques.
# Entregable Formato
E1 Diagrama de arquitectura con el flujo completo de extremo a
extremo, dirección del tráfico y límites de confianza

PNG o PDF

E2 Documento de decisiones: mínimo 5 decisiones, cada una con las
opciones evaluadas y el criterio de elección

4 a 8 páginas

E3 Plan de direccionamiento: tabla de subredes con rango, tamaño y
propósito

Tabla
E4 Modelo de seguridad: autenticación, autorización, TLS, secretos e
IAM

Sección de E2
E5 Supuestos, riesgos y trade-offs asumidos Lista
4. Reglas
• Se permite usar asistentes de IA y documentación oficial. La defensa oral es sin apoyo.
• Si falta un dato, asúmelo y decláralo. No preguntes por cada detalle.
• Pesa más un diseño correcto y bien argumentado que uno extenso y superficial.