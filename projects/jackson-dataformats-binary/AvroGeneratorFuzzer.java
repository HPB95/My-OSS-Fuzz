// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
///////////////////////////////////////////////////////////////////////////
import com.code_intelligence.jazzer.api.FuzzedDataProvider;
import com.fasterxml.jackson.core.io.SerializedString;
import com.fasterxml.jackson.dataformat.avro.AvroFactory;
import com.fasterxml.jackson.dataformat.avro.AvroFactoryBuilder;
import com.fasterxml.jackson.dataformat.avro.AvroGenerator;
import com.fasterxml.jackson.dataformat.avro.AvroMapper;
import com.fasterxml.jackson.dataformat.avro.schema.AvroSchemaGenerator;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.math.BigDecimal;
import java.math.BigInteger;
import java.util.EnumSet;
import java.util.List;

/** This fuzzer targets the methods of AvroGenerator */
public class AvroGeneratorFuzzer {
  private static final String[] fieldNameChoice = {
    "string", "i", "bo", "b", "c", "d", "f", "s", "l",
    "bd", "ba", "da", "la", "ia", "obj"
  };

  public static void fuzzerTestOneInput(FuzzedDataProvider data) {
    try {
      // Retrieve set of AvroGenerator.Feature
      EnumSet<AvroGenerator.Feature> featureSet = EnumSet.allOf(AvroGenerator.Feature.class);

      // Create and configure AvroMapper
      AvroFactoryBuilder avroFactoryBuilder;
      if (data.consumeBoolean()) {
        avroFactoryBuilder = AvroFactory.builderWithApacheDecoder();
      } else {
        avroFactoryBuilder = AvroFactory.builderWithNativeDecoder();
      }
      AvroMapper mapper =
          new AvroMapper(
              avroFactoryBuilder
                  .enable(data.pickValue(featureSet))
                  .disable(data.pickValue(featureSet))
                  .build());

      // Failsafe logic
      if (mapper == null) {
        return;
      }

      // Create and configure AvroGenerator
      AvroGenerator generator =
          ((AvroMapper) mapper).getFactory().createGenerator(new ByteArrayOutputStream());
      for (AvroGenerator.Feature feature : featureSet) {
        generator.configure(feature, data.consumeBoolean());
      }

      AvroSchemaGenerator schemaGenerator = new AvroSchemaGenerator();
      mapper.acceptJsonFormatVisitor(RootType.class, schemaGenerator);

      generator.setSchema(schemaGenerator.getGeneratedSchema());
      generator.writeStartObject();

      // Fuzz methods of CBORGenerator
      String value = null;
      byte[] byteArray = null;
      generator.writeFieldName(data.pickValue(fieldNameChoice));
      switch (data.consumeInt(1, 18)) {
        case 1:
          generator.writeBoolean(data.consumeBoolean());
          break;
        case 2:
          generator.writeNull();
          break;
        case 3:
          int[] intArray = data.consumeInts(data.consumeInt(1, 5));
          generator.writeArray(intArray, 0, intArray.length);
          break;
        case 4:
          long[] longArray = data.consumeLongs(data.consumeInt(1, 5));
          generator.writeArray(longArray, 0, longArray.length);
          break;
        case 5:
          double[] doubleArray = new double[data.consumeInt(1, 5)];
          for (int i = 0; i < doubleArray.length; i++) {
            doubleArray[i] = data.consumeDouble();
          }
          generator.writeArray(doubleArray, 0, doubleArray.length);
          break;
        case 6:
          generator.writeString(data.consumeRemainingAsString());
          break;
        case 7:
          value = data.consumeRemainingAsString();
          generator.writeString(value.toCharArray(), 0, value.length());
          break;
        case 8:
          generator.writeString(new SerializedString(data.consumeRemainingAsString()));
          break;
        case 9:
          byteArray = data.consumeRemainingAsBytes();
          generator.writeRawUTF8String(byteArray, 0, byteArray.length);
          break;
        case 10:
          byteArray = data.consumeRemainingAsBytes();
          generator.writeUTF8String(byteArray, 0, byteArray.length);
          break;
        case 11:
          byteArray = data.consumeRemainingAsBytes();
          generator.writeBinary(new ByteArrayInputStream(byteArray), byteArray.length);
          break;
        case 12:
          generator.writeNumber(data.consumeInt());
          break;
        case 13:
          generator.writeNumber(data.consumeLong());
          break;
        case 14:
          generator.writeNumber(data.consumeDouble());
          break;
        case 15:
          generator.writeNumber(data.consumeFloat());
          break;
        case 16:
          generator.writeNumber(new BigDecimal(data.consumeLong()));
          break;
        case 17:
          generator.writeNumber(BigInteger.valueOf(data.consumeLong()));
          break;
        case 18:
          generator.writeNumber(data.consumeRemainingAsString());
          break;
      }

      generator.flush();
      generator.close();
    } catch (IOException | IllegalArgumentException | IllegalStateException e) {
      // Known exception
    }
  }

  private static class RootType {
    public String string;
    public int i;
    public boolean bo;
    public byte b;
    public char c;
    public double d;
    public float f;
    public short s;
    public long l;
    public BigDecimal bd;
    public byte[] ba;
    public double[] da;
    public long[] la;
    public int[] ia;
    public Object obj;
  }
}
