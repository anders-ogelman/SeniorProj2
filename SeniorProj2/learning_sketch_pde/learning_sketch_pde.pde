// Required Bluetooth methods on startup


//NOTE: RESOLUTION IS HARDCODED RIGHT NOW IN LIKE 50 DIFFERENT PLACES. DO NOT MESS WITH THE RESOLUTION!!!!!!!


import android.os.Bundle;                                 // 1
import android.content.Intent;                            // 2

import java.util.List;
import java.util.ArrayList;

import ketai.net.bluetooth.*;  
import ketai.ui.*; 
import ketai.net.*;
import oscP5.*;


import java.nio.ByteBuffer;

KetaiBluetooth bt;                                        // 3

KetaiList connectionList;                                 // 4
String info = "";                                         // 5
PVector remoteCursor = new PVector();
boolean isConfiguring = true;
String UIText;
boolean cameraDisplay = false;

int checkSendTimer = 0;

import ketai.camera.*;
KetaiCamera cam;

//where the image taken by this device will be stored that is taken to be transfered
PImage oppressionPhoto;

//photo the device got from anohter device
PImage receivedPhoto;

//boolean that says if we have an image to share or to accept
boolean hasShareableImage = false;
boolean hasAcceptedImage = false;

//may be unnecessary later, but we're using it for now
boolean hasSentImage = false;

//started the process of accepting an image
boolean beganAcceptingImage = false;

//for storing the received image
List<KetaiOSCMessage> receivedPixelOSCMessages = new ArrayList<KetaiOSCMessage>();




//temp for counting different things
int miscCounter = 0;

//variable to hold up standard messaging and prevent data loss
boolean isBusy = false;

//variable to set the number of pixels sent in a single OSC message
int pixelsPerMessage = 150;

//for measuring data integrity
double pixelsReceivedCounter = 0;
double idealPixels = 1280*768;

void setup()
{   

  //photo setup
  oppressionPhoto = new PImage(1280, 768);


  orientation(PORTRAIT);
  background(78, 93, 75);
  stroke(255);
  textSize(48);

  bt.start();                                             // 6

  //UIText =  "[b] - make this device discoverable\n" +     // 7
  //  "[d] - discover devices\n" +
  //  "[c] - pick device to connect to\n" +
  //  "[p] - list paired devices\n" +
  //  "[i] - show Bluetooth info";
  
  UIText = "placeholder UI text";

  //camera stuff
  cam = new KetaiCamera(this, 1280, 768, 30);
  cam.start();
  imageMode(CENTER);
  
  //HACKY CODE to auto add device
  if (bt.getPairedDeviceNames().size() > 0) {
    System.out.println("attempted to auto pair");
    bt.connectToDeviceByName(bt.getPairedDeviceNames().get(0));
  }
}

void draw()
{
  
  if (!isBusy && checkSendTimer >= 4900) {
    //send the checking messages every 5 seconds
    //BAD IDEA: using ints because for some reason ketai wont accept my bools
    OscMessage checkSharing = new OscMessage("/checkSharing/");
    checkSharing.add(hasShareableImage ? 1 : 0);
    checkSharing.add(hasAcceptedImage ? 1 : 0);
    
    bt.broadcast(checkSharing.getBytes());
    
    checkSendTimer = 0;
  }
  
  checkSendTimer = millis()%5000;
  
  
  
  if (isConfiguring)
  {

    ArrayList<String> devices;                            // 8
    background(78, 93, 75);

    if (key == 'i')
      info = getBluetoothInformation();                   // 9
    else
    {
      if (key == 'p')
      {
        info = "Paired Devices:\n";
        devices = bt.getPairedDeviceNames();              // 10
      } else
      {
        info = "Discovered Devices:\n";
        devices = bt.getDiscoveredDeviceNames();          // 11
      }

      for (int i=0; i < devices.size(); i++)
      {
        info += "["+i+"] "+devices.get(i).toString() + "\n";  // 12
      }
    }
    text(UIText + "\n\n" + info, 5, 200);
  } else
  {
    background(78, 93, 75);
    pushStyle();
    fill(255);
    ellipse(mouseX, mouseY, 50, 50);
    fill(0, 255, 0);
    stroke(0, 255, 0);
    ellipse(remoteCursor.x, remoteCursor.y, 50, 50);      // 13
    popStyle();
    if (cam.isStarted())
      image(cam, width/2, height/2);

    if (oppressionPhoto != null) {
      image(oppressionPhoto, 100, 700);
    }
    
    if (receivedPhoto != null) {
      image(receivedPhoto, 100, 700); 
    }
  }

  drawUI();
}

void mouseDragged()
{
  if (isConfiguring)
    return;

  if (!hasShareableImage && mouseY > 500) {
    
    //save the image in a pixel array
    cam.loadPixels();

    oppressionPhoto.loadPixels();

    for (int i = 0; i < cam.pixels.length; i++) {
      oppressionPhoto.pixels[i] = cam.pixels[i];
    }

    oppressionPhoto.updatePixels();

    //get a pixel array and turn it into a byte array
    oppressionPhoto.loadPixels();
    
    //now we do have a shareable image
    hasShareableImage = true;
  }

  //OscMessage m = new OscMessage("/remoteMouse/");          // 14
  //m.add(mouseX);
  //m.add(mouseY);

  //bt.broadcast(m.getBytes());                              // 15
  //// use writeToDevice(String _devName, byte[] data) to target a specific device
  //ellipse(mouseX, mouseY, 20, 20);
  
  

}

void onBluetoothDataEvent(String who, byte[] data)         // 16
{
  if (isConfiguring)
    return;

  KetaiOSCMessage m = new KetaiOSCMessage(data);            // 17
  if (m.isValid())
  {
    if (m.checkAddrPattern("/remoteMouse/"))
    {
      if (m.checkTypetag("ii"))                             // 18
      {
        remoteCursor.x = m.get(0).intValue();
        remoteCursor.y = m.get(1).intValue();
      }
    }
    else if(m.checkAddrPattern("/photoChunk/")) {
      
      beganAcceptingImage = true;
      
      if(m.get(0).intValue() == -1) {
        isBusy = false;
        System.out.println("image received");
        hasAcceptedImage = true;
        
        //get the image set up and stored after receiving
        receivedPhoto = recievedPhotoAssembler();
        
      } else {
        isBusy = true; 
      
      
        System.out.println("data chunks received:" + miscCounter);
        
        receivedPixelOSCMessages.add(m);
        
        
        miscCounter += 1;
      }
      
    }
    //format: sending boolean, recieving boolean
    else if(m.checkAddrPattern("/checkSharing/")) {
      System.out.println("got check sharing message");
              
      if (m.checkTypetag("ii"))                             // 18
      {
        
        //if you're getting these messages and were previously being sent an image, the image must have been received
        if(beganAcceptingImage) {
          System.out.println("image received");
          hasAcceptedImage = true;
          //resetting this variable so it could conceivably support another transmission, though I will probably have to change a ton more stuff before that's possible.
          beganAcceptingImage = false;
        }
        
         //send the image if the booleans are correct (0 means false, remember we're doing the hacky int thing)
        if (hasShareableImage && (m.get(1).intValue() == 0) && !hasSentImage) {
          System.out.println("oppression broadcasted");
          isBusy = true;
          sendOppressionPhotoAsOSC();
          hasSentImage = true;
          System.out.println("photo sent!");
          isBusy = false;
        } 
      }
      
      
    }
  }
  
   
}


void sendOppressionPhotoAsOSC() {
  
  
  
  int pixelCounter = 0;
  
  
  oppressionPhoto.loadPixels();
  
  while(pixelCounter < oppressionPhoto.pixels.length) {
   
    OscMessage oppressionPhotoChunk = new OscMessage("/photoChunk/");
    
    //the pixel offset
    oppressionPhotoChunk.add(pixelCounter);
      
    if(pixelCounter + pixelsPerMessage <= oppressionPhoto.pixels.length) {
      //adding pixelcounter pixels after the offset
      for(int i = 0; i <  pixelsPerMessage && pixelCounter < oppressionPhoto.pixels.length; i++) {
       
        oppressionPhotoChunk.add(oppressionPhoto.pixels[pixelCounter]);
        
        pixelCounter++;
        
      }
    } else {
      
        oppressionPhotoChunk.add(pixelCounter);
        while(pixelCounter < oppressionPhoto.pixels.length) {
       
          oppressionPhotoChunk.add(oppressionPhoto.pixels[pixelCounter]);
          
          pixelCounter++;
        
        }
        //fill out the rest of the way with zero
        int remainingLength = oppressionPhoto.pixels.length % pixelsPerMessage;
        for(int i = 0; i < remainingLength; i++) {
         oppressionPhotoChunk.add(0); 
          
        }
    }
    
   
    bt.broadcast(oppressionPhotoChunk.getBytes());
    
    //prevents messages from tripping over themselves
    delay(25);
    
    print("sending photo...");
    
    
  }
  
  OscMessage oppressionPhotoChunk = new OscMessage("/photoChunk/");
  oppressionPhotoChunk.add(-1);
  oppressionPhotoChunk.add(-1);
  bt.broadcast(oppressionPhotoChunk.getBytes());
  
  
}

//camera preview 
void onCameraPreviewEvent() {                                 // 4
  cam.read();                                                 // 5
}


//function contains code to render a newly recieved oppression photo
PImage recievedPhotoAssembler() {
  
  PImage storer = new PImage(1280, 768);
  storer.loadPixels();
  
  for(int i = 0; i < receivedPixelOSCMessages.size(); i++) {
   
    KetaiOSCMessage m = receivedPixelOSCMessages.get(i);
    
    
    int offset = m.get(0).intValue();
    
    for (int j = 1; j <= pixelsPerMessage && offset + j < storer.pixels.length; j++) {
      storer.pixels[j+offset] = m.get(j).intValue();
      pixelsReceivedCounter += 1.0;
    }
    
  }
  
  storer.updatePixels();
  
  double dataIntegrity = ((pixelsReceivedCounter/idealPixels)*100);
  System.out.println("data integrity: " + (dataIntegrity));
  
 return storer;
  
}

String getBluetoothInformation()                             // 19
{
  String btInfo = "Server Running: ";
  btInfo += bt.isStarted() + "\n";
  btInfo += "Discovering: " + bt.isDiscovering() + "\n";
  btInfo += "Device Discoverable: "+bt.isDiscoverable() + "\n";
  btInfo += "\nConnected Devices: \n";

  ArrayList<String> devices = bt.getConnectedDeviceNames();  // 20
  for (String device : devices)
  {
    btInfo+= device+"\n";
  }

  return btInfo;
}

 

 
