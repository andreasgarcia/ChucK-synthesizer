 // number of the device to open (see: chuck --probe)
0 => int device;
// get command line
if( me.args() ) me.arg(0) => Std.atoi => device;

// the midi event
MidiIn min;
// the message for retrieving data
MidiMsg msg;


// open the device
if( !min.open( device ) ) me.exit();

// print out device that was opened
<<< "MIDI device:", min.num(), " -> ", min.name() >>>;
10 => int numVoices;
20 => int numLayers;
float series[numLayers];
// ratio is the linearity of the ratio between the partials.
1.0 => float ratio;
// modParam is the parameter that is changed by the mod wheel
0.0 => float modParam;
// array of keys numbers that are currently pressed. -1 if not pressed
int pressedKeys[numVoices];
// array of how hard keys were struck (range 6-130)
int keyForce[numVoices];
// int keyForces[numVoices];
SinOsc voices[numVoices][numLayers];
Envelope voiceEnvelope[numVoices];
Step unity => Envelope ratioEnvelope => blackhole;
unity => Envelope modEnvelope => blackhole;
ratioEnvelope.value(ratio);
ratioEnvelope.duration(0.05::second);
modEnvelope.value(modParam);
modEnvelope.duration(0.05::second);
//ratioEnvelope.duration(0.1::second);
Gain outGain =>JCRev reverb => dac;

reverb.mix(0.05);
outGain.gain(0.1/numVoices);
// initialize arrays
for(int i; i < numVoices; i++){
    -1 => pressedKeys[i];
    for(int l; l < numLayers; l++){
        voices[i][l] => voiceEnvelope[i];
        voices[i][l].gain(series[l]+Math.sin(modParam*l));
    }
    voiceEnvelope[i]=>outGain;
    voiceEnvelope[i].value(0);
    voiceEnvelope[i].duration(0.05::second);
}

64.0 => float pitchWheelCenter;
63.0 => float pitchWheelRange;
0.5 => float ratioRange;
ratioRange/pitchWheelRange => float ratioScale;
fun void updateRatio(int val){
    //ratioEnvelope.target(Math.pow(2,(val-pitchWheelCenter)*ratioScale));
    ratioEnvelope.target((val-pitchWheelCenter)*ratioScale+1);
}

127.0 => float modWheelRange;
2.0 => float modParamRange;
modParamRange/modWheelRange => float modScale;
fun void updateModParam(int val){
    modEnvelope.target(val*modScale);
}

fun void smoothUpdates(){
    while(true){
        ratioEnvelope.last() => ratio;
        modEnvelope.last() => modParam;
        for(int i; i<numVoices;i++){
            updateVoice(i);
        }
        20::samp=>now;
    }
}

1 => int partialFreqMode;

now => time start;
fun void updateVoice(int index){
    (now - start)/second => float elapsed;
    if(pressedKeys[index]==-1) return;
    Std.mtof(pressedKeys[index]) => float fundFreq;
    (keyForce[index]-5)*0.08 => float force;
    for(int l; l< numLayers; l++){
        if(partialFreqMode==3){
            voices[index][l].freq(fundFreq*Math.pow(2.0,-4*(ratio-1)/12)*(l+1+2*(ratio-1)));         
        }
        if(partialFreqMode==2){
            voices[index][l].freq(fundFreq*((l+1)*(1.0-2*(ratio-1.0)*(l+1.0-numLayers)/numLayers)-2*(ratio-1)));
        }
        if(partialFreqMode==1){
            voices[index][l].freq(fundFreq*Math.pow(l+1,ratio));
        }
        Math.pow(4.0/(l+1),modParam*2) => float amplitude;
        amplitude*Math.sin((0.25*pi*modParam+1)*l)=>amplitude;
        amplitude*(1.0+0.2*Math.sin(3 *pi*elapsed*l))=>amplitude;
        voices[index][l].gain(amplitude);
    }
}

fun void playKey(int keyVal, int force){
    for(int i; i < numVoices; i++){
        if(pressedKeys[i] == -1){
            keyVal => pressedKeys[i];
            force => keyForce[i];
            updateVoice(i);
            voiceEnvelope[i].target((force-5)*0.05);
            break;
        }
    }
}

fun void liftKey(int keyVal){
    for(int i; i < numVoices; i++){
        if(pressedKeys[i] == keyVal){
            voiceEnvelope[i].keyOff();
            -1 => pressedKeys[i];
            break;
        }
    }
}


Hid hi;
HidMsg kbmsg;
// open keyboard (get device number from command line)
if( !hi.openKeyboard( device ) ) me.exit();
<<< "keyboard '" + hi.name() + "' ready", "" >>>;

// infinite event loop
fun void keyboardControl(){
    while( true )
    {
        // wait on event
        hi => now;
        // get one or more messages
        while( hi.recv( kbmsg ) )
        {
             // check for action type
             if( kbmsg.isButtonDown() )
             {
                 if(kbmsg.which == 44){
                     //space button
                     //if(pitchChangeRate==0) -0.5=>pitchChangeRate;
                     //else 0=>pitchChangeRate;
                     //0.0=>pitchOffset;
                     (partialFreqMode+1)%3+1=>partialFreqMode;
                     <<<"now in mode ", partialFreqMode>>>;
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


spork ~keyboardControl();

spork ~smoothUpdates();

<<<"now in mode 1. Press space to change modes">>>; 
while( true )
{
    // wait on the event 'min'
    min => now;
    while( min.recv(msg) )
    {
        if(msg.data1 == 144) playKey(msg.data2, msg.data3);
        if(msg.data1 == 128) liftKey(msg.data2);
        if(msg.data1 == 224) updateRatio(msg.data3);                
        if(msg.data1 == 176) updateModParam(msg.data3);
    }
}
