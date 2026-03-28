# ── SES 도메인 인증 ───────────────────────────────────────────────
# codecaine.store 도메인 인증 → noreply@codecaine.store 등 발신 가능

resource "aws_ses_domain_identity" "main" {
  domain = var.domain_name
}

# Route53에 SES 도메인 인증 TXT 레코드 추가
resource "aws_route53_record" "ses_verification" {
  provider = aws.route53
  zone_id  = local.zone_id
  name     = "_amazonses.${var.domain_name}"
  type     = "TXT"
  ttl      = 600
  records  = [aws_ses_domain_identity.main.verification_token]
}

# SES 도메인 인증 완료 대기
resource "aws_ses_domain_identity_verification" "main" {
  domain = aws_ses_domain_identity.main.domain

  depends_on = [aws_route53_record.ses_verification]
}

# DKIM 설정 (이메일 위변조 방지)
resource "aws_ses_domain_dkim" "main" {
  domain = aws_ses_domain_identity.main.domain
}

# Route53에 DKIM CNAME 레코드 3개 추가
resource "aws_route53_record" "ses_dkim" {
  provider = aws.route53
  count    = 3
  zone_id  = local.zone_id
  name     = "${aws_ses_domain_dkim.main.dkim_tokens[count.index]}._domainkey.${var.domain_name}"
  type     = "CNAME"
  ttl      = 600
  records  = ["${aws_ses_domain_dkim.main.dkim_tokens[count.index]}.dkim.amazonses.com"]
}

# MAIL FROM 도메인 설정 (SPF 레코드용)
resource "aws_ses_domain_mail_from" "main" {
  domain           = aws_ses_domain_identity.main.domain
  mail_from_domain = "mail.${var.domain_name}"
}

resource "aws_route53_record" "ses_mail_from_mx" {
  provider = aws.route53
  zone_id  = local.zone_id
  name     = aws_ses_domain_mail_from.main.mail_from_domain
  type     = "MX"
  ttl      = 600
  records  = ["10 feedback-smtp.${var.region}.amazonses.com"]
}

resource "aws_route53_record" "ses_mail_from_spf" {
  provider = aws.route53
  zone_id  = local.zone_id
  name     = aws_ses_domain_mail_from.main.mail_from_domain
  type     = "TXT"
  ttl      = 600
  records  = ["v=spf1 include:amazonses.com ~all"]
}
