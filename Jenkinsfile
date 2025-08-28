pipeline {
  agent any

  environment {
    APP_IMAGE = "calc-app:test"
  }

  stages {
    stage('Build Docker image') {
      steps {
        sh '''
          echo "🔨 בונה Docker image..."
          docker build -t $APP_IMAGE .
        '''
      }
    }

    stage('Run tests') {
      steps {
        sh '''
          echo "🧪 מריץ טסטים..."
          docker run --rm $APP_IMAGE pytest -q || exit 1
        '''
      }
    }
  }

  post {
    success {
      echo "✅ Build + Tests הצליחו!"
    }
    failure {
      echo "❌ Build או Tests נכשלו."
    }
  }
}

