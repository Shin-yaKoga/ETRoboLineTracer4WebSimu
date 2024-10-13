basic_linetrace = function(v, duration, p_gain)
    for i in range(0, duration)
        ref = ev3_color_sensor_get_reflect
        cv = (ref - 18) * p_gain
        ev3_motor_set_power_left(v - cv)
        ev3_motor_set_power_right(v + cv)
        yield
    end for
end function

smooth_linetrace = function(v, duration, p_gain, i_gain)
    integral = 0
    for i in range(0, duration)
        ref = ev3_color_sensor_get_reflect
        diff = ref - 18
        if (diff == 0) then
            integral = 0
            cv = 0
        else
            integral = integral + diff
            cv = (diff * p_gain) + (integral * i_gain)
        end if
        ev3_motor_set_power_left(v - cv)
        ev3_motor_set_power_right(v + cv)
        yield
    end for
end function

start_sequence = function(target_v)
    v = 60
    while v < target_v
        basic_linetrace(v, 20)
        v = v + 10
    end while
end function

// run to the end of second corner
basic_linetrace(50, 200, 2)
basic_linetrace(100, 760, 1)
smooth_linetrace(100, 515, 4, 1/100)
basic_linetrace(100, 240, 1)
smooth_linetrace(100, 380, 4, 1/100)

