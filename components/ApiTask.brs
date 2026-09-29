sub Init()

    m.top.functionName = "Ejecutar"

end sub


sub Ejecutar()

    endpoint = m.top.endpoint
    baseUrl = m.top.baseUrl


    if endpoint = "" or baseUrl = ""

        m.top.error = "Configura la URL base de la API y el endpoint"

        return

    end if


    url = baseUrl + endpoint


    print "======================================"

    print "API REQUEST"

    print url

    print "======================================"


    transfer = CreateObject("roUrlTransfer")

    transfer.SetUrl(url)

    transfer.SetRequest("GET")


    response = transfer.GetToString()


    if response = invalid

        m.top.error = "No se pudo conectar con el servidor"

        return

    end if


    print "RESPUESTA:"

    print response


    resultado = ParseJson(response)


    if resultado = invalid

        m.top.error = "Respuesta JSON inválida"

        return

    end if


    m.top.result = resultado

end sub