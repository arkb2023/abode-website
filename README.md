# Abode Website Application

This repository contains a simple Apache HTTPd-based web application that serves as the deployment target for the **[Abode Website GitOps CI/CD Pipeline](https://github.com/arkb2023/devops-assignments/tree/main/project1)** capstone project.

The Application repository is forked from [hshar/website](https://github.com/hshar/website.git) per project requirement. Enhanced with complete **CI/CD pipeline configuration** enabling automated GitHub → CodeBuild → DockerHub → Jenkins → Docker deployment workflow.

**Pipeline Components:**

- **Dockerfile:** Containerizes application using base image `hshar/webapp`, copies code to `/var/www/html`.
- **buildspec.yml:** Defines CodeBuild phases for source checkout, Docker build, DockerHub push with branch-specific tagging (`main-v1.0-xx`, `develop-v1.0-xx`).
- **Groovy Pipeline Files:** Orchestrate Jenkins MultiJob phases:
  - `pipelines/build-pipeline.groovy`: Executes `scripts/smoke.sh` for image sanity checks (pull, smoke test, metadata)  
  - `pipelines/test-pipeline.groovy`: Executes `scripts/test.sh` to run validation tests on Test server
  - `pipelines/deploy-pipeline.groovy`: Executes `scripts/deploy.sh` for production deployment(main branch only), exposes port 80.

---

## Repository Structure
```bash
.
├── Dockerfile                          # Container image definition
├── buildspec.yml                       # AWS CodeBuild configuration
├── config.properties                   # Pipeline configuration
├── images/
│   └── github3.jpg
├── index.html                          # Web application
├── pipelines/                          # Jenkins MultiJob phase orchestrators
│   ├── build-pipeline.groovy           # Calls scripts/smoke.sh
│   ├── test-pipeline.groovy            # Calls scripts/test.sh
│   └── deploy-pipeline.groovy          # Calls scripts/deploy.sh
└── scripts/                            # Executable pipeline stages
    ├── smoke.sh                        # Docker image sanity check
    ├── test.sh                         # Validation tests
    └── deploy.sh                       # Production deployment
```

---