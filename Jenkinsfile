pipeline {
  agent none
  options { timestamps(); ansiColor('xterm') }

  environment {
    AWS_REGION = "us-east-1"
    ECR_REPO   = "orbak-app1"
  }

  stages {

    stage('Prepare vars') {
      agent { label 'built-in' }
      steps {
        script {
          // האם זה PR (ב-Multibranch CHANGE_ID קיים ב-PRים)
          env.IS_PR = env.CHANGE_ID ? "true" : "false"
          env.IMAGE_TAG = env.CHANGE_ID ? "pr-${env.CHANGE_ID}-${env.BUILD_NUMBER}" : "build-${env.BUILD_NUMBER}"
          echo "IS_PR=${env.IS_PR}, IMAGE_TAG=${env.IMAGE_TAG}"
        }
      }
    }

    stage('Build Docker image') {
      agent {
        docker {
          image 'docker:27.1.2-cli'
          args '-u root -v /var/run/docker.sock:/var/run/docker.sock'
          reuseNode true
        }
      }
      steps {
        sh '''
          echo "🔨 Building Docker image..."
          docker version
          docker build -t ${ECR_REPO}:${IMAGE_TAG} .
        '''
      }
    }

    stage('Run tests') {
      // מריצים בדיקות בסביבת Python (לא חייב בתוך ה-image של האפליקציה)
      agent {
        docker {
          image 'python:3.12-slim'
          args '-u root'
          reuseNode true
        }
      }
      steps {
        sh '''
          python --version
          pip install --no-cache-dir -r requirements.txt || true
          pip install --no-cache-dir pytest pytest-cov
          mkdir -p reports
          pytest -q --junitxml=reports/junit.xml
        '''
      }
      post {
        always {
          junit 'reports/junit.xml'
          archiveArtifacts artifacts: 'reports/**', fingerprint: false
        }
      }
    }

    stage('Login & Push to ECR') {
      agent {
        docker {
          image 'docker:27.1.2-cli'
          args '-u root -v /var/run/docker.sock:/var/run/docker.sock'
          reuseNode true
        }
      }
      steps {
        sh '''
          set -e
          echo "🧰 Installing AWS CLI..."
          apk add --no-cache curl unzip >/dev/null
          TMPDIR=$(mktemp -d)
          curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TMPDIR/awscliv2.zip"
          unzip -q "$TMPDIR/awscliv2.zip" -d "$TMPDIR"
          $TMPDIR/aws/install -i /usr/local/aws-cli -b /usr/local/bin >/dev/null
          aws --version

          echo "🔐 Fetching account id..."
          ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
          ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
          IMAGE_URI="${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"

          echo "🔑 Logging in to ECR..."
          aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

          echo "🏷️  Tag & Push..."
          docker tag ${ECR_REPO}:${IMAGE_TAG} ${IMAGE_URI}
          docker push ${IMAGE_URI}

          if [ "${IS_PR}" = "false" ]; then
            echo "📌 Also tagging :latest for master"
            docker tag ${IMAGE_URI} ${ECR_REGISTRY}/${ECR_REPO}:latest
            docker push ${ECR_REGISTRY}/${ECR_REPO}:latest
          fi

          echo "✅ Pushed: ${IMAGE_URI}"
        '''
      }
    }
  }

  post {
    success { echo "✅ Build + Tests + Push ל-ECR הצליחו!" }
    failure { echo "❌ משהו נכשל בפייפליין." }
  }
}
