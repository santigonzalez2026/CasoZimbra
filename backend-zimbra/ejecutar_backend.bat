@echo off
chcp 65001 >nul
echo ============================================================================
echo   INICIANDO BACK-END TRANSACCIONAL ZIMBRA (SPRING BOOT - PUERTO 8080)
echo ============================================================================
cd /d "%~dp0"
"C:\apache-maven-3.9.16\bin\mvn.cmd" spring-boot:run
pause
