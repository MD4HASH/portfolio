# terraform/pipeline.tf
# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codestarconnections_connection
resource "aws_codestarconnections_connection" "github" {
  name          = "github-connection"
  provider_type = "GitHub"
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codebuild_project
resource "aws_codebuild_project" "build" {
  name         = "my-app-build"
  service_role = module.prerequisites.codebuild_role_arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "ENV"
      value = "dev"
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/codepipeline
resource "aws_codepipeline" "pipeline" {
  name     = "my-app-pipeline"
  role_arn = module.prerequisites.codepipeline_role_arn

  artifact_store {
    location = module.prerequisites.pipeline_artifacts_bucket_name
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = aws_codestarconnections_connection.github.arn
        FullRepositoryId = "YOUR_GITHUB_USERNAME/YOUR_REPO_NAME" # Replace, e.g., "johndoe/my-app"
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      configuration = {
        ProjectName = aws_codebuild_project.build.name
      }
    }
  }

  stage {
    name = "Deploy"
    action {
      name     = "ManualApproval"
      category = "Approval"
      owner    = "AWS"
      provider = "Manual"
      version  = "1"
      configuration = {
        CustomData = "Approve Terraform apply for production"
      }
    }
  }

  stage {
    name = "Apply"
    action {
      name            = "TerraformApply"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      version         = "1"
      input_artifacts = ["source_output"]
      configuration = {
        ProjectName = aws_codebuild_project.build.name
        EnvironmentVariables = jsonencode([
          { name = "ENV", value = "prod", type = "PLAINTEXT" }
        ])
      }
    }
  }
}
