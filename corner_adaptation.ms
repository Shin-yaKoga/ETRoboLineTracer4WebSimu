RingBuf = {
    "SIZE":8,
    "body":[0, 0, 0, 0, 0, 0, 0, 0],
    "head": 0,
    "tail": 0,
}

RingBuf.is_empty = function()
    return (self.head == self.tail)
end function

RingBuf.is_full = function()
    return (self.tail - self.head == RingBuf.SIZE)
end function

RingBuf.push = function(val)
    if self.is_full() then
        print "RingBuf is full!"
    else
        self.body[self.tail % RingBuf.SIZE] = val
        self.tail = self.tail + 1
    end if
end function

RingBuf.pop = function()
    if self.is_empty() then
        print "RingBuf is empty!"
        return 0
    else
        val = self.body[self.head % RingBuf.SIZE]
        self.head = self.head + 1
        return val
    end if
end function

RingBuf.clear = function()
    self.head = 0
	self.tail = 0
end function

MovingIntegral = {
    "ringbuf": new RingBuf,
    "value": 0,
}

MovingIntegral.push = function(val)
    if self.ringbuf.is_full() then
        self.value = self.value + (val - self.ringbuf.pop())
    else
        self.value = self.value + val
    end if
    self.ringbuf.push(val)
end function

MovingIntegral.reset = function()
    self.value = 0
	self.ringbuf.clear()
end function

Params = {
    "speed":0,
    "i_gain":1/100,
    "show_count":false,
    "count":0,
}
params = new Params

DirectionMonitor = {
    "STRAIGHT":0,
    "TURN_LEFT":1,
    "TURN_RIGHT":2,
    "l_angle_sum": 0,
    "r_angle_sum": 0,
    "prev_diff": 0,
    "curr_diff": 0,
    "integral": new MovingIntegral,
    "curr_dir":0,  // STRAIGHT
    "consecutives":0,
    "effective_dir":0,
    "in_stable":true,
}

DirectionMonitor.dir_str = function(dir)
    if (dir == 0) then
        return "STRAIGHT"
    else if (dir == 1) then
        return "TURN_LEFT"
    else
        return "TURN_RIGHT"
end function

DirectionMonitor.reset = function()
    self.l_angle_sum = ev3_motor_get_counts_left()
    self.r_angle_sum = ev3_motor_get_counts_right()
    self.curr_diff = self.l_angle_sum - self.r_angle_sum
	self.prev_diff = self.curr_diff
	self.integral.reset()
end function

DirectionMonitor.update = function()
    self.l_angle_sum = ev3_motor_get_counts_left()
    self.r_angle_sum = ev3_motor_get_counts_right()
    self.prev_diff = self.curr_diff
    self.curr_diff = self.l_angle_sum - self.r_angle_sum
    self.integral.push(self.curr_diff - self.prev_diff)
    iv = self.integral.value
    dir = self.curr_dir
    if (abs(iv) > 3) then
        if (iv < 0) then
            dir = DirectionMonitor.TURN_LEFT
        else
            dir = DirectionMonitor.TURN_RIGHT
        end if
    else if (abs(iv) < 1) then
        dir = DirectionMonitor.STRAIGHT
    end if
    if (dir != self.curr_dir) then
        self.curr_dir = dir
        self.consecutives = 0
    else
        self.consecutives = self.consecutives + 1
        if (self.consecutives == 5) then
            if (self.in_stable == true) then
                if (self.effective_dir == DirectionMonitor.STRAIGHT) then
                    print "may be enter a corner"
                end if
                params.i_gain = 1/20
                self.in_stable = false
            end if
        else if (self.consecutives == 70) then
            if (self.effective_dir != self.curr_dir) then
                self.effective_dir = self.curr_dir
                print "new dir: " + self.dir_str(dir)
                self.in_stable = true
            end if
        end if
    end if
end function

dm = new DirectionMonitor

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
    Params.speed = v
    Params.i_gain = i_gain
    integral = 0
    for i in range(0, duration)
        dm.update()
        v = params.speed
        i_gain = params.i_gain
        ref = ev3_color_sensor_get_reflect
        diff = ref - 18
        if (diff == 0) then
            integral = 0
            cv = 0
        else
            intgral = integral + diff
            cv = (diff * p_gain) + (integral * i_gain)
            if (abs(cv) > v) then
//                print "too large control value: " + p + ", v: " + v
                integral = 0
                v = 0
            end if
        end if
        ev3_motor_set_power_left(v - cv)
        ev3_motor_set_power_right(v + cv)
//        print i
//        if params.show_count then
//            print params.count
//            params.count = params.count + 1
//        end if
        yield
    end for
end function

start_sequence = function(target_v)
    v = 60
    while v < target_v
        basic_linetrace(v, 20, 2)
        v = v + 10
    end while
end function


start_sequence(100)
dm.in_stable = true
dm.effective_dir = -1
//smooth_linetrace(100, 10000, 4, 1/100)
smooth_linetrace(100, 3600, 4, 1/100)
