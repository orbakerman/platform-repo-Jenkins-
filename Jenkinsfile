pipeline {
  agent {
    docker {
      image 'python:3.12-slim'
      args '-u root -v /var/run/docker.sock:/var/run/docker.sock'
    }
  }

  environment {
    AWS_REGION = "us-east-1"
    ECR_REPO   = "orbak-app1"
  }

  stages {
    stage('Install tools') {
      steps {
        sh '''
          pip install --no-cache-dir awscli pytest
        '''
      }
    }

    stage('Build Docker image') {
      steps {
        sh '''
          echo "🔨 בונה Docker image..."
          docker build -t local:latest .
        '''
      }
    }

    stage('Run tests') {
      steps {
        sh '''
          echo "🧪 מריץ טסטים..."
          docker run --rm local:latest pytest -q || exit 1
        '''
      }
    }

    stage('Login to ECR') {
      steps {
        sh '''
          echo "🔑 מתחבר ל-ECR..."
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
          aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
          echo $ECR_REGISTRY > .ecr_registry
        '''
      }
    }

    stage('Push to ECR') {
      steps {
        sh '''
          echo "🚀 מעלה image ל-ECR..."
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          ECR_REGISTRY="$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"
          IMAGE_URI="$ECR_REGISTRY/$ECR_REPO:build-$BUILD_NUMBER"

          docker tag local:latest $IMAGE_URI
          docker push $IMAGE_URI
        '''
      }
    }
  }

  post {
    success {
      echo "✅ Build + Tests + Push ל-ECR הצליחו!"
    }
    failure {
      echo "❌ משהו נכשל בפייפליין."
    }
  }
}
