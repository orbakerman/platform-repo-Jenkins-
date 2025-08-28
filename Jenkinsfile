pipeline {
  agent {
    docker { image 'python:3.12-slim' }
  }

  stages {
    stage('Build Docker image') {
      steps {
        sh '''
          echo "🔨 בונה Docker image..."
          docker --version
        '''
      }
    }

    stage('Run tests') {
      steps {
        sh '''
          echo "📦 מתקין pytest..."
          pip install --no-cache-dir pytest
          echo "🧪 מריץ טסטים..."
          pytest -q || exit 1
        '''
      }
    }
  }

  post {
    success {
      echo "✅ Build + Tests הצליחו!"
    }
    failure {
      echo "❌ Builו Tests ."
    }
  }
}

