import java.util.Arrays;
import my.edu.tarumt.collaborative_asg.NdefApdu;
public class NdefApduCheck {
    static void check(boolean value){if(!value)throw new AssertionError("NFC protocol check failed");}
    public static void main(String[] args){
        NdefApdu protocol=new NdefApdu();byte[] payload={ (byte)0xD1,1,5,0x54,2,0x65,0x6E,0x48,0x69};
        check(Arrays.equals(protocol.process(new byte[]{0,0xA4-256,4,0,7,(byte)0xD2,0x76,0,0,(byte)0x85,1,1,0},payload),new byte[]{(byte)0x90,0}));
        check(protocol.process(new byte[]{0,(byte)0xB0,0,0,2},payload)[0]==0x69);
        protocol.process(new byte[]{0,(byte)0xA4,0,0x0C,2,(byte)0xE1,4},payload);
        check(Arrays.equals(protocol.process(new byte[]{0,(byte)0xB0,0,0,2},payload),new byte[]{0,9,(byte)0x90,0}));
        byte[] result=protocol.process(new byte[]{0,(byte)0xB0,0,2,0},payload);
        check(Arrays.equals(Arrays.copyOf(result,result.length-2),payload));check(result[result.length-2]==(byte)0x90);
        check(protocol.process(new byte[]{0,(byte)0xB0,0,99,2},payload)[0]==0x6B);
        check(protocol.process(new byte[]{0,(byte)0xB0,0,0,2},null)[0]==0x69);
        protocol.reset();check(protocol.process(new byte[]{0,(byte)0xB0,0,0,2},payload)[0]==0x69);
        System.out.println("Seven actual Type 4 NFC protocol checks passed.");
    }
}
