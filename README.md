# AWS Resume Challenge

Cloud resume built with AWS services and automated CI/CD pipeline.

## Architecture

- **Frontend**: Static site hosted on S3 with CloudFront CDN
- **Backend**: Lambda function with API Gateway for visitor counter
- **Database**: DynamoDB for persistent storage
- **Infrastructure**: Terraform for Infrastructure as Code
- **CI/CD**: GitHub Actions for automated deployment

## Features

- Serverless architecture
- Automated deployments on push to main
- Lambda function testing with pytest
- CloudFront invalidation for instant updates
- Custom domain with HTTPS
- CORS-enabled API

## Deployment

The site automatically deploys when changes are pushed to the main branch:
1. Tests run on the Lambda function
2. Frontend syncs to S3
3. CloudFront cache invalidates
4. Lambda function updates

## Live Site

[austin-mundy-resume.com](https://austin-mundy-resume.com)