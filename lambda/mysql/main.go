package main

import (
	"database/sql"
	"log"
	"os"

	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/ssm"
	_ "github.com/go-sql-driver/mysql"
)

func main() {
	lambda.Start(handler)
}

func handler() {
	rdsHost := os.Getenv("RDS_HOST")
	rdsUser := os.Getenv("RDS_USERNAME_SSM_KEY")
	rdsPass := os.Getenv("RDS_PASSWORD_SSM_KEY")
	rdsUserValue := GetSSMValue(rdsUser)
	rdsPassValue := GetSSMValue(rdsPass)

	CreateUser(rdsUserValue, rdsPassValue, rdsHost)
}

func GetSSMValue(paramName string) string {
	sess := session.Must(session.NewSession())
	ssmClient := ssm.New(sess)
	input := &ssm.GetParameterInput{
		Name:           aws.String(paramName),
		WithDecryption: aws.Bool(true),
	}

	result, err := ssmClient.GetParameter(input)
	if err != nil {
		log.Fatal(err)
	}

	encryptedValue := result.Parameter.Value
	return *encryptedValue
}

func CreateUser(username string, password string, hostname string) {
	// create a new database connection
	db, err := sql.Open("mysql", username+":"+password+"@tcp("+hostname+":3306)/")
	if err != nil {
		panic(err.Error())
	}
	defer db.Close()

	log.Println("mysql", username+":"+password+"@tcp("+hostname+":3306)/")

	log.Println("9")

	// create a new database
	_, err = db.Exec("CREATE DATABASE mydatabase")
	log.Println("13")
	if err != nil {
		log.Println("14")
		panic(err.Error())
		log.Println("15")
	}
	log.Println("10")

	// create a new user
	_, err = db.Exec("CREATE USER 'myuser'@'%' IDENTIFIED BY 'mypassword'")
	if err != nil {
		panic(err.Error())
	}
	log.Println("11")

	// grant all privileges on the database to the user
	_, err = db.Exec("GRANT ALL PRIVILEGES ON mydatabase.* TO 'myuser'@'%'")
	if err != nil {
		panic(err.Error())
	}
	log.Println("12")
}
