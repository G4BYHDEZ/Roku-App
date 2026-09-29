sub Init()

    m.dateLabel = m.top.FindNode("dateLabel")

    m.timeLabel = m.top.FindNode("timeLabel")

    ActualizarFechaHora()

    m.timer = CreateObject("roSGNode", "Timer")

    m.timer.duration = 1

    m.timer.repeat = true

    m.timer.ObserveField("fire", "ActualizarFechaHora")

    m.timer.control = "start"

    m.top.AppendChild(m.timer)

end sub


sub ActualizarFechaHora()

    fecha = CreateObject("roDateTime")

    fecha.ToLocalTime()


    dia = fecha.GetDayOfMonth()

    mes = fecha.GetMonth()

    anio = fecha.GetYear()

    hora = fecha.GetHours()

    minutos = fecha.GetMinutes()

    segundos = fecha.GetSeconds()


    if dia < 10

        diaTexto = "0" + dia.ToStr()

    else

        diaTexto = dia.ToStr()

    end if


    if mes < 10

        mesTexto = "0" + mes.ToStr()

    else

        mesTexto = mes.ToStr()

    end if


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


    if segundos < 10

        segundosTexto = "0" + segundos.ToStr()

    else

        segundosTexto = segundos.ToStr()

    end if


    m.dateLabel.text = diaTexto + "/" + mesTexto + "/" + anio.ToStr()


    m.timeLabel.text = horaTexto + ":" + minutosTexto + ":" + segundosTexto

end sub