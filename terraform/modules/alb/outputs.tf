output "alb_dns_name" {
  description = "DNS name of the ALB — use as CNAME target in Route 53."
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Hosted zone ID of the ALB — use for Route 53 alias records."
  value       = aws_lb.main.zone_id
}

output "target_group_arn" {
  description = "ALB target group ARN — passed to the ECS service load_balancer block."
  value       = aws_lb_target_group.app.arn
}

output "alb_arn_suffix" {
  description = "ALB ARN suffix — used in CloudWatch metrics and ALB-based auto-scaling policies."
  value       = aws_lb.main.arn_suffix
}

output "target_group_arn_suffix" {
  description = "Target group ARN suffix — used in ALB-based auto-scaling policies."
  value       = aws_lb_target_group.app.arn_suffix
}
