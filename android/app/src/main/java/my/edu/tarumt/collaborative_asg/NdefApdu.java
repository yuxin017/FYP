package my.edu.tarumt.collaborative_asg;

import java.util.Arrays;

/** Read-only NFC Forum Type 4 NDEF file protocol. No credential is written to disk. */
public final class NdefApdu {
    private int selected = 0;
    private static final byte[] OK = {(byte)0x90, 0x00};
    private static final byte[] CC = {0x00,0x0F,0x20,0x00,(byte)0xFF,0x00,(byte)0xFF,0x04,0x06,(byte)0xE1,0x04,0x0F,(byte)0xFF,0x00,(byte)0xFF};
    public void reset() { selected = 0; }
    public byte[] process(byte[] command, byte[] ndef) {
        if (ndef == null || ndef.length == 0) return new byte[]{0x69,(byte)0x85};
        if (command == null || command.length < 4 || command[0] != 0) return new byte[]{0x6D,0};
        int instruction = command[1] & 0xFF;
        if (instruction == 0xA4 && command.length >= 7) {
            int count=command[4]&0xFF;
            if(command.length<5+count) return new byte[]{0x67,0};
            byte[] data=Arrays.copyOfRange(command,5,5+count);
            if(command[2]==0x04 && Arrays.equals(data,new byte[]{(byte)0xD2,0x76,0,0, (byte)0x85,0x01,0x01})) { selected=0;return OK.clone(); }
            if(command[2]==0 && count==2 && data[0]==(byte)0xE1 && (data[1]==0x03 || data[1]==0x04)) { selected=data[1];return OK.clone(); }
            return new byte[]{0x6A,(byte)0x82};
        }
        if(instruction==0xB0 && command.length==5) {
            byte[] file;
            if(selected==0x03)file=CC;
            else if(selected==0x04){file=new byte[ndef.length+2];file[0]=(byte)(ndef.length>>8);file[1]=(byte)ndef.length;System.arraycopy(ndef,0,file,2,ndef.length);}
            else return new byte[]{0x69,(byte)0x86};
            int offset=((command[2]&0x7F)<<8)|(command[3]&0xFF),length=command[4]&0xFF;
            if(length==0)length=256;
            if(offset>=file.length)return new byte[]{0x6B,0};
            int end=Math.min(file.length,offset+length);
            byte[] response=Arrays.copyOfRange(file,offset,end+2);response[response.length-2]=(byte)0x90;response[response.length-1]=0;
            return response;
        }
        return new byte[]{0x6D,0};
    }
}
