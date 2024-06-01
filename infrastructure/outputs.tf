output "LB_PUBLIC_IP" {
    value = google_compute_global_forwarding_rule.lb_public.ip_address
}