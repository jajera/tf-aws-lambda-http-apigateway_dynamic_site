# tf-aws-lambda-http-apigateway_dynamic_site

## build

```terraform
terraform init
```

```terraform
terraform apply --auto-approve
```

## test

### home page

```bash
curl https://brpypbym3l.execute-api.ap-southeast-2.amazonaws.com/home
```

```text
"Hello from Lambda!"
```

### colors page

return all colors

```bash
curl -s https://brpypbym3l.execute-api.ap-southeast-2.amazonaws.com/colors | jq
```

```json
{
  "message": "Success",
  "result": [
    {
      "id": 1,
      "name": "Red",
      "hex": "#FF0000"
    },
    {
      "id": 2,
      "name": "Green",
      "hex": "#00FF00"
    },
    {
      "id": 3,
      "name": "Blue",
      "hex": "#0000FF"
    },
    {
      "id": 4,
      "name": "Yellow",
      "hex": "#FFFF00"
    },
    {
      "id": 5,
      "name": "Cyan",
      "hex": "#00FFFF"
    },
    {
      "id": 6,
      "name": "Magenta",
      "hex": "#FF00FF"
    },
    {
      "id": 7,
      "name": "Orange",
      "hex": "#FFA500"
    },
    {
      "id": 8,
      "name": "Purple",
      "hex": "#800080"
    }
  ]
}
```

return specific color

```bash
curl -s https://brpypbym3l.execute-api.ap-southeast-2.amazonaws.com/colors/1 | jq
```

```bash
{
  "message": "Success",
  "result": {
    "id": 1,
    "name": "Red",
    "hex": "#FF0000"
  }
}
```

add new color (NOTE: This addition is temporary as the data is stored only in memory.)

```bash
curl -X POST https://brpypbym3l.execute-api.ap-southeast-2.amazonaws.com/colors \
  -H "Content-Type: application/json" \
  -d '{
    "id": 9,
    "name": "Pink",
    "hex": "#FFC0CB"
  }'
```

## cleanup

```terraform
terraform destroy --auto-approve
```
