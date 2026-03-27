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

# ============================================================
# Dashboard: X-Ray Traces
# ============================================================
resource "grafana_dashboard" "xray_traces" {
  folder      = grafana_folder.cdci.id
  config_json = file("${path.module}/dashboards/xray-traces.json")
}

# ============================================================
# Dashboard: Business Overview
# ============================================================
resource "grafana_dashboard" "business_overview" {
  folder      = grafana_folder.cdci.id
  config_json = file("${path.module}/dashboards/business-overview.json")
}
