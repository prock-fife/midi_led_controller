/* MIDI LED Controller
 * ------------------- 
 * Created 05 October 2008
 * http://ragingreality.blogspot.com
 */

int ledPins[] = { 11, 10, 9, 6, 5, 3  };   // PWM pins for the LEDS
char key_state[] = { 0,0,0,0,0,0 };  // key states 0 = off, 1 = on, 2 = fade in
                                     //  3 = fade out, 4 = blink
unsigned long key_val[] = { 0,0,0,0,0,0 };

//MIDI data
char mCommand = 0;
char mChannel = 0;
char mByte1 = 0;
char mByte2 = 0;

//Misc data
int incomingByte;
int dataByte;
int lNibble;
int rNibble;

// Middle C (C3)
byte l_offset = 0x3C;

// Higher C (C4)
byte h_offset = 0x48;

// Lower C (C2)
byte m_offset = 0x30;

// Number of frames to fade and blink
unsigned long fade_time = 10000;
unsigned long blink_time = 2000;

boolean validCommand = false;

boolean readMidi()
{
  if(Serial.available() > 0) {
    incomingByte = Serial.read();
    dataByte = incomingByte&0xFF; //keep only a byte
    
    return true;
  }
  return false;
}

void setup() {
  //  Set MIDI baud rate:
  Serial.begin(31250);

  for (int i = 0; i < 6; i++) {
    pinMode(ledPins[i], OUTPUT);
  }
}

void loop() {
  if (readMidi()) {
    // save the left nibble and right nibble of the byte received
    lNibble = dataByte>>4;
    rNibble = dataByte&0x0f;  
   
    // lNibble is the MIDI command.  Check for a valid command. 
    if (lNibble == 0x09 || lNibble == 0x08) {
      validCommand = true;
      mCommand = lNibble;
      mChannel = rNibble;
      mByte1 = 0;
      mByte2 = 0;
    }
    else if (mByte1 == 0 && validCommand) {
      mByte1 = dataByte;
    }
    else if (mByte2 == 0 && validCommand && mByte1 != 0) {
      mByte2 = dataByte; 
      
      // Full MIDI command was recieved.  Process it now.
      doMidiCommand(mCommand,mChannel,mByte1,mByte2);
    }
  }
  updateKeys();
}

// Executes the MIDI Command.  I have yet to implement the channel
void doMidiCommand(char cmd, char channel, char data1, char data2) {
  if (cmd == 0x09 && data2 > 0) {
    if (data1 >= l_offset && data1 < (l_offset+0x06)) {
      digitalWrite(ledPins[data1-l_offset], HIGH);
      key_state[data1-l_offset] = 1;
      key_val[data1-l_offset] = fade_time;
    }
    // Fading in
    else if(data1 >= h_offset && data1 < (h_offset+0x06)) {
      key_state[data1-h_offset] = 2;
      key_val[data1-h_offset] = 1;  //start the fade in at 1 
    }
    // Blinking
    else if(data1 >= m_offset && data1 < (m_offset+0x06)) {
      key_state[data1-m_offset] = 4;
      key_val[data1-m_offset] = 0;  //start the blink on 
    }
  }
  if (cmd == 0x08 || data2 == 0) {
    // LED off
    if (data1 >= l_offset && data1 < (l_offset+0x06)) {
      digitalWrite(ledPins[data1-l_offset], LOW);
      key_state[data1-l_offset] = 0;
      key_val[data1-l_offset] = 0;
    }
    // Start fade out
    else if(data1 >= h_offset && data1 < (h_offset+0x06)) {
      key_state[data1-h_offset] = 3; // start the fade out
    } 
    // Stop blinking
    else if(data1 >= m_offset && data1 < (m_offset+0x06)) {
      digitalWrite(ledPins[data1-m_offset],LOW);
      key_state[data1-m_offset] = 0; // off
      key_val[data1-m_offset] = 0;
    } 
    
  }

  // Reset MIDI data
  mCommand = 0;
  validCommand = false;
  mChannel = 0;
  mByte1 = 0;
  mByte2 = 0;  
}


// This function updated the LEDs brightness based on the keys state and value.
void updateKeys() {
  int val = 0;
  
  for(int i = 0; i < 6; i++) {
     if (key_state[i] == 2 && key_val[i] <= fade_time) { //fade in
       analogWrite(ledPins[i], (key_val[i]*254)/fade_time);
       key_val[i] = key_val[i] + 1;
     }
     if (key_state[i] == 3 && key_val[i] > 0) { //fade out
       analogWrite(ledPins[i], (key_val[i]*254)/fade_time);
       key_val[i] = key_val[i] - 1;
     }
     if (key_state[i] == 4) {
       if(key_val[i] >= blink_time/2) {
         digitalWrite(ledPins[i], HIGH);
         key_val[i] = key_val[i] + 1;
       }
       else {
         digitalWrite(ledPins[i], LOW);
         key_val[i] = key_val[i] + 1;
       } 
       if(key_val[i] >= blink_time) {
          key_val[i] = 0; //start again 
       }
     }
     if (key_val[i] <= 0 && key_state[i] == 3) {
        key_state[i] == 0; // done the fade out
        key_val[i] = 0;
     }
  } 
}
