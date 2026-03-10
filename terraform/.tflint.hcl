# TFLint configuration
# AWS ruleset docs: https://github.com/terraform-linters/tflint-ruleset-aws

plugin "aws" {
  enabled = true
  version = "0.38.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  # Inspect local module calls so module-level issues are caught at the
  # environment root rather than requiring tflint to be run inside each module.
  call_module_type = "local"
}
