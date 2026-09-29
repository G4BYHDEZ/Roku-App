sub Init()

    m.rows = m.top.FindNode("rows")

    m.counter = m.top.FindNode("counter")

    m.message = m.top.FindNode("message")

    m.lastUpdate = m.top.FindNode("lastUpdate")

    m.apiTask = m.top.FindNode("apiTask")


    m.apiTask.ObserveField("result", "RespuestaRecibida")


    m.apiTask.ObserveField("error", "ErrorRecibido")


    CargarChecadas()


    m.timer = CreateObject("roSGNode", "Timer")

    m.timer.duration = 5

    m.timer.repeat = true

    m.timer.ObserveField("fire", "CargarChecadas")

    m.timer.control = "start"

    m.top.AppendChild(m.timer)

end sub


' ============================================================
' SOLICITAR CHECADAS
' ============================================================

sub CargarChecadas()

    print "Solicitando checadas..."

    m.message.text = "Consultando información..."


    m.apiTask.endpoint = "/checadas"

    m.apiTask.control = "RUN"

end sub


' ============================================================
' RESPUESTA
' ============================================================

sub RespuestaRecibida()

    response = m.apiTask.result


    if response = invalid

        m.message.text = "Respuesta inválida"

        return

    end if


    if response.success <> true

        m.message.text = "La API devolvió un error"

        return

    end if


    datos = response.data


    LimpiarFilas()


    if datos = invalid

        m.counter.text = "Checadas registradas: 0"

        m.message.text = "No existen checadas."

        return

    end if


    cantidad = datos.Count()


    m.counter.text = "Checadas registradas: " + cantidad.ToStr()


    if cantidad = 0

        m.message.text = "No existen checadas registradas el día de hoy."

    else

        m.message.text = ""

    end if


    y = 0


    for each empleado in datos

        CrearFila(empleado, y)

        y = y + 60

    end for


    m.lastUpdate.text = "Última actualización: " + ObtenerHoraActual()

end sub


' ============================================================
' ERROR
' ============================================================

sub ErrorRecibido()

    errorTexto = m.apiTask.error


    print "ERROR API:"

    print errorTexto


    m.counter.text = "Error de conexión"

    m.message.text = errorTexto

end sub


' ============================================================
' CREAR FILA
' ============================================================

sub CrearFila(empleado, y)

    fila = CreateObject("roSGNode", "Group")

    fila.translation = [0, y]

    fila.width = 1200

    fila.height = 55


    fondo = CreateObject("roSGNode", "Rectangle")

    fondo.width = 1200

    fondo.height = 55

    fondo.color = "0x1A2733FF"

    fila.AppendChild(fondo)


    numero = CreateObject("roSGNode", "Label")

    numero.translation = [20, 12]

    numero.width = 130

    numero.height = 30

    numero.text = TextoSeguro(empleado.numero_empleado)

    numero.color = "0xFFFFFFFF"

    numero.font = "font:SmallBoldSystemFont"

    fila.AppendChild(numero)


    nombre = CreateObject("roSGNode", "Label")

    nombre.translation = [170, 12]

    nombre.width = 300

    nombre.height = 30

    nombre.text = TextoSeguro(empleado.nombre_completo)

    nombre.color = "0xFFFFFFFF"

    nombre.font = "font:SmallSystemFont"

    fila.AppendChild(nombre)


    departamento = CreateObject("roSGNode", "Label")

    departamento.translation = [490, 12]

    departamento.width = 230

    departamento.height = 30

    departamento.text = TextoSeguro(empleado.nombre_departamento)

    departamento.color = "0xFFFFFFFF"

    departamento.font = "font:SmallSystemFont"

    fila.AppendChild(departamento)


    entrada = CreateObject("roSGNode", "Label")

    entrada.translation = [740, 12]

    entrada.width = 150

    entrada.height = 30

    entrada.text = ObtenerHoraTexto(empleado.fecha_entrada)

    entrada.color = "0xFFFFFFFF"

    entrada.font = "font:SmallSystemFont"

    fila.AppendChild(entrada)


    salida = CreateObject("roSGNode", "Label")

    salida.translation = [900, 12]

    salida.width = 150

    salida.height = 30


    if empleado.fecha_salida = invalid

        salida.text = "EN TURNO"

    else if empleado.fecha_salida = ""

        salida.text = "EN TURNO"

    else

        salida.text = ObtenerHoraTexto(empleado.fecha_salida)

    end if


    salida.color = "0xFFFFFFFF"

    salida.font = "font:SmallSystemFont"

    fila.AppendChild(salida)


    estado = CreateObject("roSGNode", "Label")

    estado.translation = [1050, 12]

    estado.width = 130

    estado.height = 30

    estado.text = TextoSeguro(empleado.estado)

    estado.color = "0xFFFFFFFF"

    estado.font = "font:SmallBoldSystemFont"

    fila.AppendChild(estado)


    m.rows.AppendChild(fila)

end sub


' ============================================================
' LIMPIAR
' ============================================================

sub LimpiarFilas()

    while m.rows.GetChildCount() > 0

        child = m.rows.GetChild(0)

        m.rows.RemoveChild(child)

    end while

end sub


' ============================================================
' TEXTO
' ============================================================

function TextoSeguro(valor)

    if valor = invalid

        return ""

    end if


    return valor.ToStr()

end function


' ============================================================
' HORA
' ============================================================

function ObtenerHoraTexto(fecha)

    if fecha = invalid

        return ""

    end if


    texto = fecha.ToStr()


    posicion = instr(1, texto, " ")


    if posicion > 0

        return mid(texto, posicion + 1, 8)

    end if


    return texto

end function


' ============================================================
' HORA ACTUAL
' ============================================================

function ObtenerHoraActual()

    fecha = CreateObject("roDateTime")

    fecha.ToLocalTime()


    hora = fecha.GetHours()

    minutos = fecha.GetMinutes()


    if hora < 10

        horaTexto = "0" + hora.ToStr()

    else

        horaTexto = hora.ToStr()

    end if


    if minutos < 10

        minutosTexto = "0" + minutos.ToStr()

    else

        minutosTexto = minutos.ToStr()

    end if


    return horaTexto + ":" + minutosTexto

end function