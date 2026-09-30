import React, { useCallback, useEffect, useState } from 'react';
import {
  ActivityIndicator,
  Alert,
  Linking,
  Modal,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import {
  Camera,
  useCameraDevice,
  useCameraPermission,
  useCodeScanner,
} from 'react-native-vision-camera';
import { SkanQRCodeClient } from 'skanqrcode';

// In a real app, inject this at build time (e.g. react-native-dotenv, EAS secrets) —
// never hardcode a production key in the bundle. sk_test_ keys are sandbox (results come back
// with environment "sandbox"); sk_live_ keys are production.
const client = new SkanQRCodeClient({ apiKey: process.env.SKANQRCODE_API_KEY });

export default function ScannerScreen() {
  const { hasPermission, requestPermission } = useCameraPermission();
  const device = useCameraDevice('back');

  const [isActive, setIsActive] = useState(true);
  const [checking, setChecking] = useState(false);
  const [pendingWarning, setPendingWarning] = useState(null); // { target, result }

  useEffect(() => {
    if (!hasPermission) requestPermission();
  }, [hasPermission, requestPermission]);

  const resumeScanning = useCallback(() => {
    setPendingWarning(null);
    setIsActive(true);
  }, []);

  const handleScan = useCallback(
    async (target) => {
      setIsActive(false);
      setChecking(true);

      let result;
      try {
        result = await client.checkUrl(target);
      } catch (err) {
        setChecking(false);
        // Fail closed: a network/timeout error never auto-opens the link. We surface
        // it and let the user explicitly decide, rather than treating "unknown" as "safe".
        Alert.alert(
          'Could not verify this link',
          `${err.message}\n\nOpen it anyway at your own risk?`,
          [
            { text: 'Cancel', style: 'cancel', onPress: resumeScanning },
            {
              text: 'Open anyway',
              style: 'destructive',
              onPress: () => {
                Linking.openURL(target);
                resumeScanning();
              },
            },
          ],
        );
        return;
      }

      setChecking(false);

      // Branch on `action` (allow / warn / block). Anything unexpected is treated as a warn,
      // never as an allow.
      if (result.action === 'allow') {
        Linking.openURL(target);
        resumeScanning();
        return;
      }

      if (result.action === 'block') {
        Alert.alert(
          'Blocked: this link looks malicious',
          `Reasons: ${result.reasons.join(', ') || 'none reported'}`,
          [{ text: 'Dismiss', onPress: resumeScanning }],
        );
        return;
      }

      // warn: don't auto-open, don't hard-block either.
      setPendingWarning({ target, result });
    },
    [resumeScanning],
  );

  const codeScanner = useCodeScanner({
    codeTypes: ['qr'],
    onCodeScanned: (codes) => {
      const value = codes[0]?.value;
      if (value && isActive) {
        handleScan(value);
      }
    },
  });

  if (!hasPermission) {
    return (
      <View style={styles.center}>
        <Text>Camera permission is required to scan QR codes.</Text>
      </View>
    );
  }

  if (!device) {
    return (
      <View style={styles.center}>
        <Text>No camera device found.</Text>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <Camera
        style={StyleSheet.absoluteFill}
        device={device}
        isActive={isActive}
        codeScanner={codeScanner}
      />

      {checking && (
        <View style={styles.overlay}>
          <ActivityIndicator size="large" color="#fff" />
          <Text style={styles.overlayText}>Checking link safety…</Text>
        </View>
      )}

      <Modal visible={pendingWarning != null} transparent animationType="fade">
        <View style={styles.modalBackdrop}>
          <View style={styles.modalCard}>
            <Text style={styles.modalTitle}>This link looks suspicious</Text>
            <Text style={styles.modalTarget}>{pendingWarning?.target}</Text>
            <Text style={styles.modalReasons}>
              {pendingWarning?.result.reasons.join(', ') || 'No specific reason reported.'}
            </Text>
            <View style={styles.modalButtons}>
              <Pressable style={styles.cancelButton} onPress={resumeScanning}>
                <Text style={styles.cancelButtonText}>Cancel</Text>
              </Pressable>
              <Pressable
                style={styles.openButton}
                onPress={() => {
                  Linking.openURL(pendingWarning.target);
                  resumeScanning();
                }}
              >
                <Text style={styles.openButtonText}>Open anyway</Text>
              </Pressable>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#000' },
  center: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 24 },
  overlay: {
    ...StyleSheet.absoluteFillObject,
    backgroundColor: 'rgba(0,0,0,0.6)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  overlayText: { color: '#fff', marginTop: 12, fontSize: 16 },
  modalBackdrop: {
    flex: 1,
    backgroundColor: 'rgba(0,0,0,0.5)',
    alignItems: 'center',
    justifyContent: 'center',
    padding: 24,
  },
  modalCard: { backgroundColor: '#fff', borderRadius: 12, padding: 20, width: '100%' },
  modalTitle: { fontSize: 18, fontWeight: '600', marginBottom: 8 },
  modalTarget: { fontSize: 14, color: '#333', marginBottom: 8 },
  modalReasons: { fontSize: 13, color: '#b91c1c', marginBottom: 20 },
  modalButtons: { flexDirection: 'row', justifyContent: 'flex-end', gap: 12 },
  cancelButton: { paddingVertical: 10, paddingHorizontal: 16 },
  cancelButtonText: { color: '#333', fontSize: 15 },
  openButton: {
    paddingVertical: 10,
    paddingHorizontal: 16,
    backgroundColor: '#dc2626',
    borderRadius: 8,
  },
  openButtonText: { color: '#fff', fontSize: 15, fontWeight: '600' },
});
