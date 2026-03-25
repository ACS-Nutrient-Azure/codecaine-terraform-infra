# ============================================================
# Grafana Folders
# ============================================================
resource "grafana_folder" "cdci" {
  title = "CDCI PRD"
}

# ============================================================
# Dashboard: Service Health (ECS + ALB)
# ============================================================
resource "grafana_dashboard" "service_health" {
  folder      = grafana_folder.cdci.id
  config_json = file("${path.module}/dashboards/service-health.json")
}
