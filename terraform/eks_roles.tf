# Create IAM Role for AWS ALB Service Account
module "load_balancer_controller_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                              = "${local.eks_iam_role_prefix}-load-balancer-controller"
  attach_load_balancer_controller_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:${local.eks_alb_service_account_name}"]
    }
  }
}

# Create K8S Service Account for AWS ALB Helm Chart
resource "kubernetes_service_account" "alb_service_account" {
  metadata {
    name      = local.eks_alb_service_account_name
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/name"      = local.eks_alb_service_account_name
      "app.kubernetes.io/component" = "controller"
    }

    annotations = {
      "eks.amazonaws.com/role-arn"               = module.load_balancer_controller_irsa_role.iam_role_arn
      "eks.amazonaws.com/sts-regional-endpoints" = "true"
    }
  }

  depends_on = [
    module.eks,
    aws_eks_node_group.eks
  ]
}

# Create ISRA Role for External DNS
module "external_dns_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                  = "${local.eks_iam_role_prefix}-external-dns"
  attach_external_dns_policy = true

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:${local.eks_external_dns_service_account_name}"]
    }
  }
}

# Create K8S Service Account for External DNS
resource "kubernetes_service_account" "external_dns_service_account" {
  metadata {
    name      = local.eks_external_dns_service_account_name
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/name"      = local.eks_external_dns_service_account_name
      "app.kubernetes.io/component" = "controller"
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = module.external_dns_irsa_role.iam_role_arn
    }
  }

  depends_on = [
    module.eks,
    aws_eks_node_group.eks
  ]
}

# Create ISRA Role for Cluster Autoscaler
module "cluster_autoscaler_irsa_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.0"

  role_name                        = "${local.eks_iam_role_prefix}-cluster-autoscaler"
  attach_cluster_autoscaler_policy = true
  cluster_autoscaler_cluster_names = [module.eks.cluster_name]

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:${local.eks_cluster_autoscaler_service_account_name}"]
    }
  }
}

# Create K8S Service Account for Cluster Autoscaler
resource "kubernetes_service_account" "cluster_autoscaler_service_account" {
  metadata {
    name      = local.eks_cluster_autoscaler_service_account_name
    namespace = "kube-system"

    labels = {
      "app.kubernetes.io/name" = local.eks_cluster_autoscaler_service_account_name
      "k8s-addon"              = "cluster-autoscaler.addons.k8s.io"
      "k8s-app"                = "cluster-autoscaler"
    }

    annotations = {
      "eks.amazonaws.com/role-arn" = module.cluster_autoscaler_irsa_role.iam_role_arn
    }
  }

  depends_on = [
    module.eks,
    aws_eks_node_group.eks
  ]
}

# # Create ISRA Role for Cert Manager
# module "cert_manager_irsa_role" {
#   source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

#   role_name                     = "${local.eks_iam_role_prefix}-cert-manager"
#   attach_cert_manager_policy    = true
#   cert_manager_hosted_zone_arns = [local.route53_zone_arn]

#   oidc_providers = {
#     ex = {
#       provider_arn               = module.eks.oidc_provider_arn
#       namespace_service_accounts = ["kube-system:${local.eks_cert_manager_service_account_name}"]
#     }
#   }
# }

# # Create K8S Service Account for Cert Manager
# resource "kubernetes_service_account" "cert_manager_service_account" {
#   metadata {
#     name      = local.eks_cert_manager_service_account_name
#     namespace = "kube-system"

#     labels = {
#       "app.kubernetes.io/name"      = local.eks_cert_manager_service_account_name
#       "app.kubernetes.io/component" = "controller"
#     }

#     annotations = {
#       "eks.amazonaws.com/role-arn" = module.cert_manager_irsa_role.iam_role_arn
#     }
#   }

#   depends_on = [
#     module.eks,
#     aws_eks_node_group.eks
#   ]
# }

# Create ISRA Role for SQS
module "sqs_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${local.eks_iam_role_prefix}-sqs"
  role_policy_arns = {
    policy = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.sqs_name}-policy",
  }

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${kubernetes_namespace.sqs_app.metadata[0].name}:${local.eks_sqs_service_account_name}"]
    }
  }

  depends_on = [
    aws_iam_policy.sqs
  ]
}

module "sqs_keda_irsa_role" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"

  role_name = "${local.eks_iam_role_prefix}-sqs-keda"
  role_policy_arns = {
    policy = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/${local.sqs_name}-keda-policy",
  }

  oidc_providers = {
    ex = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${kubernetes_namespace.keda.metadata[0].name}:keda-operator"]
    }
  }

  depends_on = [
    aws_iam_policy.sqs-keda
  ]
}
