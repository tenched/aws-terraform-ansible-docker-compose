output "region" {
  value = "${var.aws_region}"
}
output "repository_uri" {
  value = "${aws_ecr_repository.ecr_repo.repository_url}"
}

output "url" {
  value = "https://${var.domain_name}"
}

output "image_name" {
  value = "${var.docker_image}"
}

output "image_version" {
  value = "${var.docker_image_version}"
}