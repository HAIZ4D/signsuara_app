/// How bent each finger is, from a raw glove row: 0 = straight, 1 = fully bent, in the order
/// thumb, index, middle, ring, pinky. On this glove straight = HIGH and bent = LOW.
/// Ranges = 1st/99th percentiles per finger of the training recordings (signsuara_data_v2.csv);
/// the thumb's straight value ignores its occasional 4095 spikes.
const _straight = [950.0, 976.0, 830.0, 741.0, 768.0];
const _bent = [602.0, 555.0, 573.0, 509.0, 507.0];

List<double> fingerBend(List<double>? row) => [
      for (var i = 0; i < 5; i++)
        row == null ? 0.0 : ((_straight[i] - row[i]) / (_straight[i] - _bent[i])).clamp(0.0, 1.0)
    ];
