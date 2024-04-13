# SRE Challenge Project README

## Introduction

Welcome to the SRE Challenge project! This project is a simple web deployment designed to showcase various SRE (Site Reliability Engineering) tasks, including infrastructure provisioning, deployment configuration, and application serving. The project includes the following components:

1. **Terraform Templates**: These templates are used to provision the necessary infrastructure on AWS, including a load balancer, web servers, and workers.
2. **AWS CodeDeploy Deployment Config File**: This file is used to configure AWS CodeDeploy for deploying the application.
3. **Django Application**: A simple Django application is served using uWSGI and Nginx.

## SRE Tasks

As part of this challenge, you will undertake the following tasks:

1. **Study the Code Repository**: Dive into the code repository and familiarize yourself with the structure and components of the project. Based on your understanding, create a system diagram that visually represents the architecture of the project.

2. **Setup the Project**: Privately set up the project on your local environment or any cloud provider of your choice. During this process, pay attention to the following:

    a. **Identify Errors/Shortcomings**: Take note of any errors, issues, or shortcomings encountered during the setup process. Document these findings for further analysis and improvement.
    
    b. **Suggest Improvements**: Based on your experience setting up the project, propose improvements or optimizations to enhance the project's reliability, scalability, or maintainability. Consider aspects such as infrastructure automation, deployment strategies, and monitoring solutions.

## Getting Started

### Pre-requisites
You will need to install the following tools to deploy and work with the repo

1. aws-cli -> [https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

2. Terraform -> [https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli)

To get started with the SRE Challenge project, follow these steps:

1. Fork this repository [https://github.com/crazywizard254/sre-challenge](https://github.com/crazywizard254/sre-challenge) and clone to your local machine:

   ```bash
   git clone https://github.com/your-username/sre-challenge.git
    ```

2. Navigate to the project directory:

    `cd sre-challenge`

3. Study implementation of the respective components (Terraform templates, AWS CodeDeploy configuration, etc.) to set up the project and deploy the application.

4. As you proceed with the setup, document any errors encountered and areas for improvement in a separate file or document.