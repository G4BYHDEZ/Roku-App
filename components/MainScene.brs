sub Init()

    m.retardosScreen = m.top.FindNode("retardosScreen")

    m.checadasScreen = m.top.FindNode("checadasScreen")

    m.top.ObserveField("screen", "CambiarPantalla")

end sub


sub CambiarPantalla()

    if m.top.screen = "retardos"

        m.retardosScreen.visible = true

        m.checadasScreen.visible = false

    else if m.top.screen = "checadas"

        m.retardosScreen.visible = false

        m.checadasScreen.visible = true

    end if

end sub


function OnKeyEvent(key, press)

    if press = false

        return false

    end if


    if key = "left"

        m.top.screen = "retardos"

        return true

    end if


    if key = "right"

        m.top.screen = "checadas"

        return true

    end if


    return false

end function