output "fanout_topic_arn"              { value = aws_sns_topic.fanout.arn }
output "alertas_ops_queue_arn"         { value = aws_sqs_queue.alertas_ops.arn }
output "alertas_ops_queue_url"         { value = aws_sqs_queue.alertas_ops.id }
output "auditoria_financiera_queue_arn" { value = aws_sqs_queue.auditoria_financiera.arn }
output "auditoria_financiera_queue_url" { value = aws_sqs_queue.auditoria_financiera.id }
output "inventario_queue_arn"          { value = aws_sqs_queue.inventario.arn }
output "inventario_queue_url"          { value = aws_sqs_queue.inventario.id }
