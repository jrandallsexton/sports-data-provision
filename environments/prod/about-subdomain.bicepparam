using './about-subdomain.bicep'

param profileName = 'fd-sportdeets'
param hostname = 'about.sportdeets.com'
param endpointName = 'default'
param originHost = 'about-app.azurewebsites.net' // Update this to your actual origin
param originGroupName = 'about-origin-group'
param minimumTlsVersion = 'TLS12'
