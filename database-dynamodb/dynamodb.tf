# DynamoDB Tables
resource "aws_dynamodb_table" "main" {
  for_each = var.dynamodb_tables

  name         = "${var.project_name}-${var.environment}-${each.key}"
  billing_mode = each.value.billing_mode
  hash_key     = each.value.hash_key
  range_key    = each.value.range_key != "" ? each.value.range_key : null

  # Global Table configuration
  stream_enabled   = var.enable_global_table ? true : each.value.stream_enabled
  stream_view_type = var.enable_global_table ? "NEW_AND_OLD_IMAGES" : (each.value.stream_enabled ? each.value.stream_view_type : null)

  read_capacity  = each.value.billing_mode == "PROVISIONED" ? each.value.read_capacity : null
  write_capacity = each.value.billing_mode == "PROVISIONED" ? each.value.write_capacity : null

  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = each.value.global_secondary_indexes
    content {
      name            = global_secondary_index.value.name
      hash_key        = global_secondary_index.value.hash_key
      range_key       = global_secondary_index.value.range_key != "" ? global_secondary_index.value.range_key : null
      projection_type = global_secondary_index.value.projection_type
      read_capacity   = each.value.billing_mode == "PROVISIONED" ? global_secondary_index.value.read_capacity : null
      write_capacity  = each.value.billing_mode == "PROVISIONED" ? global_secondary_index.value.write_capacity : null
    }
  }

  # Global Table replicas
  dynamic "replica" {
    for_each = var.enable_global_table ? var.global_table_regions : []
    content {
      region_name = replica.value
    }
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = var.enable_dynamodb_encryption
  }

  ttl {
    enabled        = true
    attribute_name = "ttl"
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-${each.key}"
  }

  lifecycle {
    ignore_changes = [replica]
  }
}

# DynamoDB Auto Scaling (for PROVISIONED billing mode)
resource "aws_appautoscaling_target" "dynamodb_read" {
  for_each = {
    for k, v in var.dynamodb_tables : k => v
    if v.billing_mode == "PROVISIONED"
  }

  max_capacity       = 100
  min_capacity       = each.value.read_capacity
  resource_id        = "table/${aws_dynamodb_table.main[each.key].name}"
  scalable_dimension = "dynamodb:table:ReadCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_read" {
  for_each = {
    for k, v in var.dynamodb_tables : k => v
    if v.billing_mode == "PROVISIONED"
  }

  name               = "${var.project_name}-${var.environment}-${each.key}-read-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_read[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_read[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_read[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBReadCapacityUtilization"
    }
    target_value = 70.0
  }
}

resource "aws_appautoscaling_target" "dynamodb_write" {
  for_each = {
    for k, v in var.dynamodb_tables : k => v
    if v.billing_mode == "PROVISIONED"
  }

  max_capacity       = 100
  min_capacity       = each.value.write_capacity
  resource_id        = "table/${aws_dynamodb_table.main[each.key].name}"
  scalable_dimension = "dynamodb:table:WriteCapacityUnits"
  service_namespace  = "dynamodb"
}

resource "aws_appautoscaling_policy" "dynamodb_write" {
  for_each = {
    for k, v in var.dynamodb_tables : k => v
    if v.billing_mode == "PROVISIONED"
  }

  name               = "${var.project_name}-${var.environment}-${each.key}-write-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.dynamodb_write[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.dynamodb_write[each.key].scalable_dimension
  service_namespace  = aws_appautoscaling_target.dynamodb_write[each.key].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "DynamoDBWriteCapacityUtilization"
    }
    target_value = 70.0
  }
}
