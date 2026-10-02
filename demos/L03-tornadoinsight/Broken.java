import uk.ac.manchester.tornado.api.annotations.Parallel;
import uk.ac.manchester.tornado.api.types.arrays.FloatArray;

/**
 * L03 · TornadoInsight. Open this file in IntelliJ with the TornadoInsight plugin installed:
 * the static checker should flag three faults inside broken().
 */
public class Broken {

    void broken(FloatArray in, FloatArray out, int n) {
        for (@Parallel int i = 0; i < n; i++) {
            String s = "not on a GPU";          // a data type
            if (in.get(i) < 0)
                throw new RuntimeException();   // an exception
            out.set(i, recurse(in.get(i)));     // recursion
        }
    }

    static float recurse(float x) {
        if (x < 1.0f) {
            return x;
        }
        return recurse(x / 2.0f) + 1.0f;
    }
}
