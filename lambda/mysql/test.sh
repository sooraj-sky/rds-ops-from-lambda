rm example.zip
rm main
env GOOS=linux GOARCH=amd64 go build main.go
chmod 777 main
zip example.zip main 
