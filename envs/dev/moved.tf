# dev was applied when the modules were called directly from this directory.
# They now live in envs/_stack, and the two shared ones are counted.

moved {
  from = module.network
  to   = module.stack.module.network
}

moved {
  from = module.cloudsql
  to   = module.stack.module.cloudsql
}

moved {
  from = module.compute_mig
  to   = module.stack.module.compute_mig
}

moved {
  from = module.load_balancer
  to   = module.stack.module.load_balancer
}

moved {
  from = module.secrets
  to   = module.stack.module.secrets
}

moved {
  from = module.ops_vm
  to   = module.stack.module.ops_vm[0]
}

moved {
  from = module.artifact_registry
  to   = module.stack.module.artifact_registry[0]
}
