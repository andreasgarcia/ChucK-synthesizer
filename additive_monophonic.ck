// universal variables
// number of the device to open (see: chuck --probe)
0 => int device;
// get command line
if( me.args() ) me.arg(0) => Std.atoi => device;
// number of partials
20 => int numLayers;
// the left wheel. Range -1.0 to 1.0
0.0 => float lWheel;
// right wheel. Range 0.0 to 1.0
0.0 => float rWheel;
// stores the freq and amplitude of the last sound;
float lastFreq[numLayers];
float lastGain[numLayers];

44100 => int sampleRate;

////////////////////////////////////////////
////////////////////////////////////////////
// function outputs the strength of the l'th partial
// l specifies the partial. force is in range 6-130, t is time since attack
fun float partialFunction(int l,int force, float t) {
    if(l==2) return 0.0;
    (force-5.0)/130.0=> float f;
    Math.pow(1.9-f*.8,-l)=> float out;
    out*(1.0+0.3*Math.sin(pi*t+.5*pi*l))=> out;
    out/(1+l*t) => out;
    0.05 => float slide;
    lastGain[l]*(slide-Math.min(t,slide))/slide+out*Math.min(t,slide)/slide=>out;
    return out;
}

// function outputs the freqency of the l'th partial
// default to Std.mtof(keyNum)*(l+1)

fun float partialFreqFunction(int keyNum, int l,int force, float t) {
    Std.mtof(keyNum)=> float fundFreq;
    fundFreq*Math.pow(2.0,4.0*(lWheel)/12.0)=> fundFreq;
    fundFreq*(l+1)=> float out;
    //out*(1+0.09/(20.0*t+1.0)*l*rWheel)=> out;
    out*(1.0+0.05*rWheel*Math.sin(pi*t*10.0*rWheel+.25*pi*l))=> out;
    0.01*(l+1) => float slide;
    //0.014 => float slide;
    //Math.max(0,t-slide*l) => t;
    lastFreq[l]*(slide-Math.min(t,slide))/slide+out*Math.min(t,slide)/slide=>out;
    return out;
}

0.05 => float reverbLevel;
////////////////////////////////////////////
////////////////////////////////////////////

// initialization


// key that was last pressed. -1 if not pressed
int pressedKey;
// how hard key was struck (range 6-130)
int keyForce;
// when key was struck
time keyTime;
// sin oscilator for each partial
SinOsc voices[numLayers];


// output gain envelope
Envelope voiceEnvelope;
// wheel output goes through an envelope to make changes smooth.
Step unity => Envelope lWheelEnvelope => blackhole;
unity => Envelope rWheelEnvelope => blackhole;
lWheelEnvelope.value(lWheel);
lWheelEnvelope.duration(0.05::second);
rWheelEnvelope.value(rWheel);
rWheelEnvelope.duration(0.05::second);

// add reverb and send output to dac.
Gain outGain =>JCRev reverb => dac;
reverb.mix(reverbLevel);
outGain.gain(0.1);

// initialize arrays
for(0 => int l; l < numLayers; l++){
    voices[l] => voiceEnvelope;
    voices[l].gain(0.0);
}
voiceEnvelope => outGain;
voiceEnvelope.value(0.0);
voiceEnvelope.duration(0.05::second);



// Wheel setup
64.0 => float lWheelCenter;
63.0 => float lWheelRange;
1.0 => float lRange;
lRange/lWheelRange => float lScale;
// called when left wheel is moved
fun void updateLWheel(int val){
    lWheelEnvelope.target((val-lWheelCenter)*lScale);
}

127.0 => float rWheelRange;
1.0 => float rRange;
rRange/rWheelRange => float rScale;
// called when right wheel is moved
fun void updateRWheel(int val){
    rWheelEnvelope.target(val*rScale);
}

// continuous updates.
fun void smoothUpdates(){
    while(true){
        lWheelEnvelope.last() => lWheel;
        rWheelEnvelope.last() => rWheel;
        updateVoice();
        20::samp=>now;
    }
}


fun void updateVoice(){
    if(pressedKey==-1) return;
    (now - keyTime)/second => float t;
    for(0 => int l; l< numLayers; l++){
        partialFreqFunction(pressedKey,l,keyForce,t) => float freq;
        partialFunction(l,keyForce,t) => float amplitude;
        voices[l].freq(freq);
        voices[l].gain(amplitude);
    }
}

// called when key is pressed
fun void playKey(int keyVal, int force){
    keyVal => pressedKey;
    force => keyForce;
    now => keyTime;
    voiceEnvelope.target(1.0);
    for(0 => int l; l < numLayers; l++){
        voices[l].freq() => lastFreq[l];
        voices[l].gain() => lastGain[l];
    }
    updateVoice();
}

// called when key is released.
fun void liftKey(int keyVal){
    if(pressedKey == keyVal){
        voiceEnvelope.keyOff();
        -1 => pressedKey;
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
            if(msg.data1 == 144) playKey(msg.data2, msg.data3);
            if(msg.data1 == 128) liftKey(msg.data2);
            if(msg.data1 == 224) updateLWheel(msg.data3);                
            if(msg.data1 == 176) updateRWheel(msg.data3);
        }
    }
}

spork ~midiControl();
spork ~smoothUpdates();
keyboardControl();