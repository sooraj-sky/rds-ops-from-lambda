package main

import (
	"log"

	"github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/kms"
	"github.com/aws/aws-sdk-go/service/ssm"
)

func main() {
	sess := session.Must(session.NewSession())
	ssmClient := ssm.New(sess)
	kmsClient := kms.New(sess)
	paramName := "/rds/mysql/masterpassword"
	input := &ssm.GetParameterInput{
		Name:           aws.String(paramName),
		WithDecryption: aws.Bool(true),
	}

	result, err := ssmClient.GetParameter(input)
	if err != nil {
		log.Println(err)
	}

	log.Println(result.Parameter)

	encryptedValue := result.Parameter.Value
	inputs := &kms.DecryptInput{
		CiphertextBlob: []byte(*encryptedValue),
	}

	results, err := kmsClient.Decrypt(inputs)
	if err != nil {
		log.Println(err)
	}

	decryptedValue := results.Plaintext

	log.Println(decryptedValue)

}
