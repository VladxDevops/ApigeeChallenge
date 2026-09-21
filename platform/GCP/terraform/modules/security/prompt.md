I tried: 
"terraform plan -var-file="./environments/DEV/dev.tfvars" -target=module.observability"
and got the following errors: 
"│ Error: Unsupported argument
│ 
│   on modules/security/main.tf line 46, in resource "google_compute_security_policy" "api_spoke_waf":
│   46:       cel_expression = "true" # Catch-all for any unmatched traffic
│ 
│ An argument named "cel_expression" is not expected here.
╵
╷
│ Error: Unsupported argument
│ 
│   on modules/security/main.tf line 138, in resource "google_compute_security_policy" "api_spoke_waf":
│  138:         cel_expression = "true"
│ 
│ An argument named "cel_expression" is not expected here.
╵
╷
│ Error: Insufficient rate_limit_threshold blocks
│ 
│   on modules/security/main.tf line 140, in resource "google_compute_security_policy" "api_spoke_waf":
│  140:       rate_limit_options {
│ 
│ At least 1 "rate_limit_threshold" blocks are required.
╵
╷
│ Error: Unsupported argument
│ 
│   on modules/security/main.tf line 143, in resource "google_compute_security_policy" "api_spoke_waf":
│  143:         rate_limit_key   = "IP"
│ 
│ An argument named "rate_limit_key" is not expected here.
╵
╷
│ Error: Unsupported argument
│ 
│   on modules/security/main.tf line 167, in resource "google_compute_security_policy" "api_spoke_waf":
│  167:   labels = merge(
│ 
│ An argument named "labels" is not expected here.
╵
╷
│ Error: Invalid combination of arguments
│ 
│   with module.security.google_compute_firewall.default_deny_ingress,
│   on modules/security/main.tf line 189, in resource "google_compute_firewall" "default_deny_ingress":
│  189: resource "google_compute_firewall" "default_deny_ingress" {
│ 
│ "deny": one of `allow,deny` must be specified
╵
╷
│ Error: Invalid combination of arguments
│ 
│   with module.security.google_compute_firewall.default_deny_ingress,
│   on modules/security/main.tf line 189, in resource "google_compute_firewall" "default_deny_ingress":
│  189: resource "google_compute_firewall" "default_deny_ingress" {
│ 
│ "allow": one of `allow,deny` must be specified
╵
╷
│ Error: Invalid combination of arguments
│ 
│   with module.security.google_compute_firewall.default_deny_egress,
│   on modules/security/main.tf line 211, in resource "google_compute_firewall" "default_deny_egress":
│  211: resource "google_compute_firewall" "default_deny_egress" {
│ 
│ "allow": one of `allow,deny` must be specified
╵
╷
│ Error: Invalid combination of arguments
│ 
│   with module.security.google_compute_firewall.default_deny_egress,
│   on modules/security/main.tf line 211, in resource "google_compute_firewall" "default_deny_egress":
│  211: resource "google_compute_firewall" "default_deny_egress" {
│ 
│ "deny": one of `allow,deny` must be specified
╵
╷
│ Error: Unsupported attribute
│ 
│   on modules/security/main.tf line 544, in resource "google_access_context_manager_access_policy" "api_spoke_policy":
│  544:   parent = "organizations/${data.google_client_config.current.org_id}"
│ 
│ This object has no argument, nested block, or exported attribute named "org_id"." 
please fix the errors and document what was wrong and how it was fixed. Here is some documentation I found: 
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_security_policy
https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_security_policy_rule#nested_match_config
