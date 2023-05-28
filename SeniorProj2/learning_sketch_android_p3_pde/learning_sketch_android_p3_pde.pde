// Required Bluetooth methods on startup
import android.os.Bundle;                                 // 1
import android.content.Intent;                            // 2

import ketai.net.bluetooth.*;  
import ketai.ui.*; 
import ketai.net.*;
import oscP5.*;

KetaiBluetooth bt;                                        // 3

KetaiList connectionList;                                 // 4
String info = "";                                         // 5
PVector remoteCursor = new PVector();
boolean isConfiguring = true;
String UIText;

void setup()
{   
  orientation(PORTRAIT);
  background(78, 93, 75);
  stroke(255);
  textSize(48);
  bt = new KetaiBluetooth(this);                          // 2

  bt.start();                                             // 6

  UIText =  "[b] - make this device discoverable\n" +     // 7
    "[d] - discover devices\n" +
    "[c] - pick device to connect to\n" +
    "[p] - list paired devices\n" +
    "[i] - show Bluetooth info";
}
