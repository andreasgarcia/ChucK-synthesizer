// universal variables
// number of the device to open (see: chuck --probe)
0 => int device;
// get command line
if( me.args() ) me.arg(0) => Std.atoi => device;
// number of keys that can be played at a time
10 => int numVoices;
// the left wheel. Range -1.0 to 1.0
0.0 => float lWheel;
// right wheel. Range 0.0 to 1.0
0.0 => float rWheel;
44100 => int sampleRate;

////////////////////////////////////////////
////////////////////////////////////////////
0.1 => float reverbLevel;
////////////////////////////////////////////
////////////////////////////////////////////

// initialization


// array of keys numbers that are currently pressed. -1 if not pressed
int pressedKeys[numVoices];
// array of how hard keys were struck (range 6-130)
int keyForce[numVoices];
// array of when keys were struck
time keyTime[numVoices];
// output gain envelope for each voice - not used right now
Envelope voiceEnvelope[numVoices];

// add reverb and send output to dac.
Gain outGain =>JCRev reverb => dac;
reverb.mix(reverbLevel);
outGain.gain(0.05);

// initialize arrays
for(int i; i < numVoices; i++){
    -1 => pressedKeys[i];
    voiceEnvelope[i] => outGain;
    voiceEnvelope[i].value(0.0);
    voiceEnvelope[i].duration(0.05::second);
}

127.0 => float rWheelRange;
1.0 => float rRange;
rRange/rWheelRange => float rScale;
// called when right wheel is moved
fun void updateRWheel(int val){
    val*rScale => rWheel;
}



fun void playFrag(int index){
    if(pressedKeys[index] == -1) return;
    2.0*(Math.randomf()-0.5) => float r;
    Std.rand2(0,7) => int partial1;
    Std.rand2(1,10) => int partial2;
    //Math.randomf() => float r2;
    Std.mtof(pressedKeys[index])=> float baseFreq;
    baseFreq*(1.0+rWheel*0.3*r)*partial2 => float freq;
    (.1+1-rWheel)::second => dur duration;
    SqrOsc s => ADSR e => outGain;
    freq => s.freq;
    1.0 => float g => s.gain;
    e.set( 1::ms, 50::ms, .2*g, 500::ms );
    e.keyOn();
    duration => now;
    e.keyOff();
}

fun void playNote(int index){
    while(true){
        Math.randomf() => float r;// r is in [0,1]
        spork ~playFrag(index);
        (20 + 30 * r)::ms => now;
        if(pressedKeys[index] == -1){
            2::second=>now;
            break;
        }
    }
}

// called when key is pressed
fun void pressKey(int keyVal, int force){
    for(int i; i < numVoices; i++){
        if(pressedKeys[i] == -1){
            keyVal => pressedKeys[i];
            force => keyForce[i];
            now => keyTime[i];
            spork ~playNote(i);
            break;
        }
    }
}

// called when key is released.
fun void liftKey(int keyVal){
    for(int i; i < numVoices; i++){
        if(pressedKeys[i] == keyVal){
            voiceEnvelope[i].keyOff();
            -1 => pressedKeys[i];
            break;
        }
    }
}




// infinite event loop
fun void keyboardControl(){
    Hid hi;
    HidMsg kbmsg;
    // open keyboard (get device number from command line)
    if( !hi.openKeyboard( device ) ) me.exit();
    <<< "keyboard '" + hi.name() + "' ready", "" >>>;
    while( true ) {
        // wait on event
        hi => now;
        // get one or more messages
        while( hi.recv( kbmsg ) )
        {
            // check for action type
            if( kbmsg.isButtonDown() )
            {
                if(kbmsg.which == 41){
                    //esc button
                    return;
                }
                if(kbmsg.which == 29){
                    //z button
                }
                if(kbmsg.which == 27){
                    //x button
                }
            }
        }
    }
}

fun void midiControl() {
    // the midi event
    MidiIn min;
    // the message for retrieving data
    MidiMsg msg;
    // open the device
    if( !min.open( device ) ) me.exit();
    // print out device that was opened
    <<< "MIDI device:", min.num(), " -> ", min.name() >>>;
    while( true )
    {
        // wait on the event 'min'
        min => now;
        while( min.recv(msg) )
        {
            if(msg.data1 == 144) pressKey(msg.data2, msg.data3);
            if(msg.data1 == 128) liftKey(msg.data2);
            //if(msg.data1 == 224) updateLWheel(msg.data3);                
            if(msg.data1 == 176) updateRWheel(msg.data3);
        }
    }
}

spork ~midiControl();
keyboardControl();