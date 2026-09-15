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