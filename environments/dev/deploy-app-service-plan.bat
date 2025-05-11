@echo off
echo Deploying App Service Plan with S1 pricing tier...

az deployment group create --resource-group rg-sportDeets-dev --template-file ./app-service-plan.bicep

echo App Service Plan deployment completed!
pause 