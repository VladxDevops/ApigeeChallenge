+++
title = "APIgee Apps — API Proxy Bundles"
domain = "apigee"
tier = 3
topics = ["apigee", "api-proxy", "proxies", "hello-world-proxy"]
parent = "README.md"
children = []
related = [
    "Agents.md",
    "docs/architecture/traffic-flows.md",
    "docs/networking/network-architecture.md",
    "platform/GCP/terraform/modules/apigee/README.md",
    ".claude/skills/apigee-proxy-bundle/SKILL.md"
]
updated_by = "Claude"
version = "1.0"
+++

> **Parent**: [`README.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/README.md)
> **Agent rules**: [`Agents.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/APPS/APIgee/Agents.md)
> **Deployment workflow**: [`.claude/skills/apigee-proxy-bundle/SKILL.md`](file:///home/pochitawork/InterviewCloudProjects/ApigeeChallenge/.claude/skills/apigee-proxy-bundle/SKILL.md)

<!-- AI RETRIEVAL HINTS:
- Purpose: Human-facing overview of the API proxy bundles in this repo — what they are, what's here today, and how to add one.
- Questions Answered: What is an Apigee proxy? What proxies exist right now? Do proxies need their own container? How do I test one end to end?
- When to Retrieve: Orienting on this directory, or explaining the proxy layer during the oral defense.
- When NOT to Retrieve: Terraform coding rules (use Agents.md instead), or the Apigee org/instance Terraform itself (use modules/apigee/README.md).
-->

# APIgee Apps

This directory holds the **API proxy bundles** deployed into the Apigee organization that `platform/GCP/terraform/modules/apigee/` provisions.

## What a proxy bundle actually is

An Apigee API proxy is **configuration, not compute**. It's a folder of XML files — no Dockerfile, no container image, no build step. Apigee's managed runtime reads the XML directly; "deploying" a proxy means zipping the folder and uploading it to the Apigee Management API, not building and pushing an image. If you're picturing a second Cloud Run service or container for the proxy, that's not how this works — see `Agents.md` for the detail.

## What's here