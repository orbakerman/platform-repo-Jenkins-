pipeline {
  agent none
  options { timestamps(); ansiColor('xterm') }

  environment {
    AWS_REGION      = "us-east-1"
    ECR_REPO        = "orbak-app1"
    ACCOUNT_ID      = "992382545251"
    IMAGE_URI       = "${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
    PROD_HOST       = "3.85.84.65"   // ❗ תעדכן ל-IP האמיתי של ה-EC2 פרוד
    CONTAINER_PORT  = "5000"           // האפליקציה מאזינה בתוך הקונטיינר
    HOST_PORT       = "80"             // נחשוף החוצה על פורט 80
  }

  stages {

    stage('Prepare Vars') {
      agent { docker { image 'alpine:3.20' args '-u root' reuseNode true } }
      steps {
        script {
          env.IS_PR = env.CHANGE_ID ? "true" : "false"
          env.IMAGE_TAG = env.CHANGE_ID ? "pr-${env.CHANGE_ID}-${env.BUILD_NUMBER}" : "build-${env.BUILD_NUMBER}"
          echo "IS_PR=${env.IS_PR}, IMAGE_TAG=${env.IMAGE_TAG}"
        }
      }
    }

    stage('Checkout') {
      agent { docker { image 'alpine/git' args '-u root' reuseNode true } }
      steps { checkout scm }
    }

    stage('Build Docker Image') {
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
          docker build -t ${ECR_REPO}:${IMAGE_TAG} .
        '''
      }
    }

    stage('Run Tests') {
      agent {
        docker {
          image 'python:3.12-slim'
          args '-u root'
          reuseNode true
        }
      }
      steps {
        sh '''
          echo "🧪 Running tests..."
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

    stage('Push to ECR') {
      agent {
        docker {
          image 'docker:27.1.2-cli'
          args '-u root -v /var/run/docker.sock:/var/run/docker.sock'
          reuseNode true
        }
      }
      steps {
        sh '''
          echo "⬇️ Installing AWS CLI..."
          apk add --no-cache curl unzip >/dev/null
          TMPDIR=$(mktemp -d)
          curl -sSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "$TMPDIR/awscliv2.zip"
          unzip -q "$TMPDIR/awscliv2.zip" -d "$TMPDIR"
          $TMPDIR/aws/install -i /usr/local/aws-cli -b /usr/local/bin >/dev/null

          ECR_REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
          IMAGE="${ECR_REGISTRY}/${ECR_REPO}:${IMAGE_TAG}"

          echo "🔑 Logging in to ECR..."
          aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

          echo "📤 Tagging & pushing image..."
          docker tag ${ECR_REPO}:${IMAGE_TAG} ${IMAGE}
          docker push ${IMAGE}

          if [ "${IS_PR}" = "false" ]; then
            echo "📤 Tagging as latest..."
            docker tag ${IMAGE} ${ECR_REGISTRY}/${ECR_REPO}:latest
            docker push ${ECR_REGISTRY}/${ECR_REPO}:latest
          fi
        '''
      }
    }

    stage('Deploy to Production') {
      when { allOf { branch 'master'; expression { env.IS_PR == "false" } } }
      agent { docker { image 'alpine:3.20' args '-u root -v /root/.ssh:/root/.ssh' reuseNode true } }
      steps {
        sshagent(credentials: ['prod-ec2-ssh']) {
          sh '''
            ssh -o StrictHostKeyChecking=no ec2-user@${PROD_HOST} "bash -s" <<'EOSH'
            set -e
            ACCOUNT_ID=${ACCOUNT_ID}
            REGION=${AWS_REGION}
            REPO=${ECR_REPO}
            TAG=latest
            ECR="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

            echo "🔑 Logging in to ECR..."
            aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ECR

            echo "📥 Pulling image..."
            docker pull $ECR/$REPO:$TAG

            echo "🛑 Stopping old container..."
            docker stop app || true
            docker rm app || true

            echo "🚀 Running new container..."
            docker run -d --name app --restart unless-stopped -p ${HOST_PORT}:${CONTAINER_PORT} $ECR/$REPO:$TAG
            EOSH
          '''
        }
      }
    }

    stage('Health Check') {
      when { allOf { branch 'master'; expression { env.IS_PR == "false" } } }
      agent { docker { image 'alpine:3.20' args '-u root' reuseNode true } }
      steps {
        sh '''
          echo "🔍 Checking health endpoint..."
          ok=0
          for i in $(seq 1 10); do
            code=$(curl -s -o /dev/null -w "%{http_code}" http://${PROD_HOST}/health || true)
            echo "Attempt $i -> HTTP $code"
            if [ "$code" = "200" ]; then ok=1; break; fi
            sleep $((i*2))
          done
          if [ "$ok" -ne 1 ]; then
            echo "❌ Health check failed"
            exit 1
          fi
          echo "✅ Health check OK"
        '''
      }
    }
  }

  post {
    always { echo "Pipeline finished with status: ${currentBuild.currentResult}" }
  }
}

