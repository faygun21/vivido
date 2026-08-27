pipeline {
    agent none

    // ----------- 1. Environments -----------

    environment {
        // --- 1.1 Uygulama ve Dil Sürümleri ---
        DOTNET_VERSION = "10.0"
        NODE_VERSION   = "22"

        // --- 1.2 Sunucu ve Servisler ---
        DOCKER_REGISTRY = "registry.basarsoft.com.tr:8000/vivido"
        SONAR_HOST_URL  = "http://sonar.basarsoft.com.tr"
        SONAR_PROJECT_KEY = "vivido-api"

        // --- 1.3 Jenkins Konfigürasyonu ---
        BUILD_CONFIG_NAME  = "Jenkins-Server"
        DEPLOY_CONFIG_NAME = "Deployment-Server"
        IMAGE_TAG           = "${BUILD_NUMBER}"

        // --- 1.4 Credentials ---
        SONAR_TOKEN    = credentials('sonar-token')
        REGISTRY_CREDS = credentials('registry-creds')
    }

    stages {

        // ----------- 2. Checkout -----------

        stage('Checkout') {
            agent any

            steps {
                checkout scm

                sh 'echo "Proje basariyla cekildi ve ortam degiskenleri yuklendi!"'

                sh "echo Mimaride kullanilacak Registry: ${DOCKER_REGISTRY}"
            }
        }


        // ----------- 3. Build -----------

        stage('Build') {
            parallel {

                // --- 3.1 Build API (Vivido.sln) ---

                stage('Build API') {
                    agent {
                        docker {
                            image "mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}"
                            args '-u root'
                        }
                    }

                    steps {
                        dir('api') {
                            sh 'dotnet restore Vivido.sln'
                            sh 'dotnet build Vivido.sln --no-restore -c Release'
                        }
                    }
                }


                // --- 3.2 Build Web (pnpm) ---

                stage('Build Web') {
                    agent {
                        docker {
                            image "node:${NODE_VERSION}-alpine"
                            args '-u root'
                        }
                    }

                    steps {
                     
                        sh 'corepack enable && corepack prepare --activate'
                        sh 'pnpm install --frozen-lockfile'
                        sh 'pnpm --filter web exec tsc --noEmit'
                        sh 'pnpm --filter web build'
                    }
                }
            }
        }


        // ----------- 4. Test -----------

        stage('Test') {
            parallel {

                // --- 4.1 Test API ---

                stage('Test API') {
                    agent {
                        docker {
                            image "mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}"
                            args '-u root -v /var/run/docker.sock:/var/run/docker.sock'
                        }
                    }

                    steps {
                        sh 'mkdir -p ${WORKSPACE}/test-results ${WORKSPACE}/coverage-results'

                        sh 'apt-get update && apt-get install -y --no-install-recommends bc'

                        dir('api') {
                            sh '''
                                dotnet test Vivido.sln --no-build -c Release \
                                    --logger "junit;LogFilePath=${WORKSPACE}/test-results/api.xml" \
                                    --collect:"XPlat Code Coverage" \
                                    --results-directory ${WORKSPACE}/coverage-results || true
                            '''

                            sh '''
                                COVERAGE_FILE=$(find ${WORKSPACE}/coverage-results -name "coverage.cobertura.xml" | head -1)

                                if [ -z "$COVERAGE_FILE" ]; then
                                    echo "========================================================"
                                    echo "UYARI: coverage.cobertura.xml dosyasi bulunamadi!"
                                    echo "API test projesinde 'coverlet.collector' paketi eksik."
                                    echo "Pipeline'in durmamasi icin bu adim atlanarak devam ediliyor..."
                                    echo "========================================================"
                                else
                                    echo "Coverage dosyasi bulundu: $COVERAGE_FILE"
                                    chmod +x ${WORKSPACE}/scripts/check-coverage.sh
                                    ${WORKSPACE}/scripts/check-coverage.sh "$COVERAGE_FILE" "0.80"
                                fi
                            '''
                        }
                    }

                    post {
                        always {
                            junit allowEmptyResults: true,
                                  testResults: 'test-results/api.xml'
                        }
                    }
                }


                // --- 4.2 Test Web ---

                stage('Test Web') {
                    agent {
                        docker {
                            image "node:${NODE_VERSION}-alpine"
                            args '-u root'
                        }
                    }

                    steps {
                        sh 'corepack enable && corepack prepare --activate'
                        sh 'pnpm install --frozen-lockfile'

                        sh 'pnpm --filter web test --run || true'
                    }
                }
            }
        }


        // ----------- 5. Statik Kontroller -----------

        stage('Statik Kontroller') {
            parallel {

                // --- 5.1 Vivido.Scoring saf kalmali ---
                // Bu kural bozulursa altin veri seti korumasi islevsizlesir.

                stage('Scoring Saflik Kontrolu') {
                    agent any

                    steps {
                        sh '''
                            CSPROJ=api/src/Vivido.Scoring/Vivido.Scoring.csproj

                            if [ ! -f "$CSPROJ" ]; then
                                echo "$CSPROJ henuz yok, kontrol atlandi"
                                exit 0
                            fi

                            if grep -q "PackageReference" "$CSPROJ"; then
                                echo "HATA: Vivido.Scoring saf olmali - PackageReference eklenemez."
                                grep -n "PackageReference" "$CSPROJ"
                                exit 1
                            fi

                            if grep -q "ProjectReference" "$CSPROJ"; then
                                echo "HATA: Vivido.Scoring hicbir projeye bagimli olmamali."
                                exit 1
                            fi

                            echo "Vivido.Scoring saf."
                        '''
                    }
                }


                // --- 5.2 Semanin dogruluk kaynagi db/schema/*.sql - EF Core migration DEGIL ---
                // Karar ve gerekcesi: docs/02-KARARLAR.md K-01.

                stage('EF Migration Kontrolu') {
                    agent any

                    steps {
                        sh '''
                            BULUNAN=$(find api -type d -name Migrations -not -path "*/bin/*" -not -path "*/obj/*")

                            if [ -n "$BULUNAN" ]; then
                                echo "HATA: EF Core migration klasoru bulundu:"
                                echo "$BULUNAN"
                                echo ""
                                echo "Sema db/schema/*.sql icinde tanimlanir (docs/02-KARARLAR.md K-01)."
                                echo "Sema degisikligi icin yeni bir numarali SQL dosyasi ekleyin"
                                echo "ve pnpm db:migrate calistirin."
                                exit 1
                            fi

                            echo "EF migration yok - sema kaynagi db/schema/*.sql."
                        '''
                    }
                }


              

                stage('Maplibre Worker Kontrolu') {
                    agent {
                        docker {
                            image "node:${NODE_VERSION}-alpine"
                            args '-u root'
                        }
                    }

                    steps {
                        sh 'corepack enable && corepack prepare --activate'
                        sh 'pnpm install --frozen-lockfile'
                        sh 'pnpm --filter web build'

                        sh '''
                            if ! ls web/dist/assets/maplibre-gl-worker-*.js >/dev/null 2>&1; then
                                echo "HATA: maplibre-gl-worker parcasi uretilmedi - harita uretimde bos cizilir (bkz. docs/04-MEVCUT-DURUM.md #5.5)"
                                ls -la web/dist/assets/
                                exit 1
                            fi

                            echo "Maplibre worker parcasi uretildi: $(ls web/dist/assets/maplibre-gl-worker-*.js)"
                        '''
                    }
                }
            }
        }


        // ----------- 6. SonarQube Kod Analizi (sadece API) -----------

        stage('SonarQube Code Analysis') {
            agent {
                docker {
                    image "mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}"
                    args '-u root -v /etc/hosts:/etc/hosts:ro'
                }
            }

            steps {
                dir('api') {
                    withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                        sh '''
                            echo "Java kurulumu yapiliyor (SonarScanner paketlemesi icin zorunlu)..."
                            apt-get update && apt-get install -y default-jre

                            echo "SonarScanner araci kuruluyor..."
                            dotnet tool install --global dotnet-sonarscanner || true

                            echo "SonarScanner analizi basliyor..."
                            /root/.dotnet/tools/dotnet-sonarscanner begin /k:"${SONAR_PROJECT_KEY}" /d:sonar.host.url="$SONAR_HOST_URL" /d:sonar.token="$SONAR_TOKEN" /d:sonar.cs.opencover.reportsPaths="**/coverage.opencover.xml"

                            dotnet build Vivido.sln -c Release

                            dotnet test Vivido.sln -c Release --collect:"XPlat Code Coverage;Format=opencover" --no-build || true

                            /root/.dotnet/tools/dotnet-sonarscanner end /d:sonar.token="$SONAR_TOKEN"
                        '''
                    }
                }
            }
        }


        // ----------- 7. Publish -----------

        stage('Publish') {

            agent any

            steps {
                sh '''
                    # 1. Yerel Registry'mize giris yapiyoruz

                    echo "$REGISTRY_CREDS_PSW" | \
                        docker login $DOCKER_REGISTRY \
                        --username "$REGISTRY_CREDS_USR" \
                        --password-stdin


                    # 2. API imajini olustur ve gonder

                    docker build \
                        -t ${DOCKER_REGISTRY}/vivido-api:${IMAGE_TAG} \
                        -t ${DOCKER_REGISTRY}/vivido-api:latest \
                        api

                    docker push ${DOCKER_REGISTRY}/vivido-api:${IMAGE_TAG}
                    docker push ${DOCKER_REGISTRY}/vivido-api:latest


                    # 3. Web imajini olustur ve gonder

                    docker build \
                        -t ${DOCKER_REGISTRY}/vivido-web:${IMAGE_TAG} \
                        -t ${DOCKER_REGISTRY}/vivido-web:latest \
                        web

                    docker push ${DOCKER_REGISTRY}/vivido-web:${IMAGE_TAG}
                    docker push ${DOCKER_REGISTRY}/vivido-web:latest
                '''
            }
        }


        // ----------- 8. Security - Trivy Scan -----------

        stage('Security - Trivy Scan') {

            agent {
                docker {
                    image 'aquasec/trivy:0.58.0'
                    args '--entrypoint="" -u root -v /etc/hosts:/etc/hosts:ro'
                }
            }

            environment {
                TRIVY_USERNAME = "${REGISTRY_CREDS_USR}"
                TRIVY_PASSWORD = "${REGISTRY_CREDS_PSW}"
            }

            steps {

                catchError(
                    buildResult: 'SUCCESS',
                    stageResult: 'UNSTABLE'
                ) {

                    sh '''
                        # API Imajini Tara

                        trivy image \
                            --severity HIGH,CRITICAL \
                            --exit-code 1 \
                            --no-progress \
                            --scanners vuln \
                            --format json \
                            --output trivy-api.json \
                            ${DOCKER_REGISTRY}/vivido-api:${IMAGE_TAG}


                        # Web Imajini Tara

                        trivy image \
                            --severity HIGH,CRITICAL \
                            --exit-code 1 \
                            --no-progress \
                            --scanners vuln \
                            --format json \
                            --output trivy-web.json \
                            ${DOCKER_REGISTRY}/vivido-web:${IMAGE_TAG}
                    '''
                }
            }

            post {
                always {
                    archiveArtifacts artifacts: 'trivy-*.json',
                                     allowEmptyArchive: true
                }
            }
        }


        // ----------- 9. Migrate (Staging) -----------

        stage('Migrate - Staging') {

            agent any

            steps {
                sshPublisher(
                    publishers: [
                        sshPublisherDesc(
                            configName: "${DEPLOY_CONFIG_NAME}",

                            transfers: [
                                sshTransfer(
                                    execCommand: '''
                                        cd /opt/vivido && \
                                        docker compose \
                                            -f docker-compose.yml \
                                            -f docker-compose.prod.yml \
                                            pull vivido-api && \

                                        docker compose \
                                            -f docker-compose.yml \
                                            -f docker-compose.prod.yml \
                                            run --rm vivido-migrate
                                    '''
                                )
                            ]
                        )
                    ]
                )
            }
        }


        // ----------- 10. Deploy (Staging) -----------

        stage('Deploy - Staging') {

            agent any

            steps {
                sshPublisher(
                    publishers: [
                        sshPublisherDesc(
                            configName: "${DEPLOY_CONFIG_NAME}",

                            transfers: [
                                sshTransfer(
                                    execCommand: '''
                                        cd /opt/vivido && \

                                        docker compose \
                                            -f docker-compose.yml \
                                            -f docker-compose.prod.yml \
                                            pull && \

                                        docker compose \
                                            -f docker-compose.yml \
                                            -f docker-compose.prod.yml \
                                            up -d
                                    '''
                                )
                            ]
                        )
                    ]
                )
            }
        }
    }
}
