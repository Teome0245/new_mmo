import java.io.*;
import javax.xml.transform.*;
import javax.xml.transform.stream.*;

public class idl_compiler {
    public static void main(String[] args) throws Exception {
        File idlDir = new File("src");
        processDirectory(idlDir);
    }

    private static void processDirectory(File dir) throws Exception {
        for (File f : dir.listFiles()) {
            if (f.isDirectory()) {
                processDirectory(f);
            } else if (f.getName().endsWith(".idl")) {
                compileIDL(f);
            }
        }
    }

    private static void compileIDL(File idlFile) throws Exception {
        String base = idlFile.getAbsolutePath().replace(".idl", "");
        transform(idlFile, "tools/idl/idl2cpp.xsl", base + ".cpp");
        transform(idlFile, "tools/idl/idl2h.xsl", base + ".h");
        System.out.println("Generated: " + base + ".cpp / .h");
    }

    private static void transform(File xml, String xslPath, String outPath) throws Exception {
        TransformerFactory factory = TransformerFactory.newInstance();
        Transformer transformer = factory.newTransformer(new StreamSource(new File(xslPath)));
        transformer.transform(new StreamSource(xml), new StreamResult(new File(outPath)));
    }
}
