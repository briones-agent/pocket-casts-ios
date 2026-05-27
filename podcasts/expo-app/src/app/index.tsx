import {
  popToNative,
  useSharedState,
  sendMessage,
} from 'expo-brownfield';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  View,
  useColorScheme,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { Spacing } from '@/constants/theme';

interface LifecycleEvent {
  id: number;
  name: string;
  at: string;
  detail?: string;
}

const POCKETCASTS_RED = '#F43E37';

export default function LifecycleTrace() {
  const scheme = useColorScheme();
  const cardBg = scheme === 'dark' ? '#1C1C1E' : '#F2F2F7';
  const subtle = scheme === 'dark' ? '#3A3A3C' : '#E5E5EA';
  const muted = scheme === 'dark' ? '#8E8E93' : '#6E6E73';

  const [events] = useSharedState<LifecycleEvent[]>('lifecycleEvents', []);
  const [activeSubscribers] = useSharedState<number>('activeSubscribers', 0);
  const [foregroundCount] = useSharedState<number>('foregroundCount', 0);
  const [backgroundCount] = useSharedState<number>('backgroundCount', 0);
  const [memoryWarnings] = useSharedState<number>('memoryWarnings', 0);

  return (
    <ThemedView style={styles.root}>
      <SafeAreaView style={styles.safe} edges={['top', 'bottom']}>
        <View style={[styles.header, { borderBottomColor: subtle }]}>
          <ThemedText style={styles.headerTitle}>Lifecycle Trace</ThemedText>
          <Pressable
            onPress={() => popToNative(true)}
            hitSlop={8}
            style={({ pressed }) => [
              styles.closeBtn,
              { backgroundColor: POCKETCASTS_RED, opacity: pressed ? 0.6 : 1 },
            ]}
          >
            <ThemedText style={styles.closeText}>Done</ThemedText>
          </Pressable>
        </View>

        <ScrollView
          contentContainerStyle={styles.scroll}
          showsVerticalScrollIndicator={false}
        >
          <View style={styles.hero}>
            <View style={[styles.icon, { backgroundColor: POCKETCASTS_RED }]}>
              <ThemedText style={styles.iconGlyph}>▶</ThemedText>
            </View>
            <ThemedText type="title" style={styles.title}>
              UIApplicationDelegate events
            </ThemedText>
            <ThemedText style={[styles.subtitle, { color: muted }]}>
              Live feed from{' '}
              <ThemedText style={styles.code}>
                ExpoAppDelegateSubscriberManager
              </ThemedText>
              {' '}— host AppDelegate forwards every lifecycle event into the
              embedded Expo runtime.
            </ThemedText>
          </View>

          <View style={styles.statsRow}>
            <Stat
              label="Subscribers"
              value={String(activeSubscribers ?? 0)}
              bg={cardBg}
              accent={POCKETCASTS_RED}
            />
            <Stat
              label="Foreground"
              value={String(foregroundCount ?? 0)}
              bg={cardBg}
            />
            <Stat
              label="Background"
              value={String(backgroundCount ?? 0)}
              bg={cardBg}
            />
            <Stat
              label="Memory⚠"
              value={String(memoryWarnings ?? 0)}
              bg={cardBg}
            />
          </View>

          <Pressable
            onPress={() => sendMessage({ type: 'CLEAR_EVENTS' })}
            style={({ pressed }) => [
              styles.actionRow,
              { backgroundColor: cardBg, opacity: pressed ? 0.7 : 1 },
            ]}
          >
            <View style={{ flex: 1 }}>
              <ThemedText style={styles.actionTitle}>
                Clear lifecycle log
              </ThemedText>
              <ThemedText style={[styles.actionSubtitle, { color: muted }]}>
                Sends a CLEAR_EVENTS message back to the subscriber
              </ThemedText>
            </View>
            <ThemedText style={[styles.chevron, { color: POCKETCASTS_RED }]}>
              ×
            </ThemedText>
          </Pressable>

          <ThemedText style={[styles.section, { color: muted }]}>
            Recent events · newest first
          </ThemedText>

          <View style={[styles.list, { backgroundColor: cardBg }]}>
            {(events ?? []).length === 0 && (
              <View style={[styles.row, { justifyContent: 'center' }]}>
                <ThemedText style={[styles.rowDomain, { color: muted }]}>
                  Waiting for the next lifecycle event…
                </ThemedText>
              </View>
            )}
            {(events ?? []).map((e, idx) => (
              <View
                key={e.id}
                style={[
                  styles.row,
                  idx < (events?.length ?? 0) - 1 && {
                    borderBottomColor: subtle,
                    borderBottomWidth: StyleSheet.hairlineWidth,
                  },
                ]}
              >
                <View style={[styles.eventDot, { backgroundColor: dotColor(e.name) }]} />
                <View style={{ flex: 1 }}>
                  <ThemedText style={styles.rowTitle} numberOfLines={1}>
                    {e.name}
                  </ThemedText>
                  {e.detail && (
                    <ThemedText
                      style={[styles.rowDomain, { color: muted }]}
                      numberOfLines={1}
                    >
                      {e.detail}
                    </ThemedText>
                  )}
                </View>
                <ThemedText style={[styles.eventTime, { color: muted }]}>
                  {e.at}
                </ThemedText>
              </View>
            ))}
          </View>
        </ScrollView>
      </SafeAreaView>
    </ThemedView>
  );
}

function Stat({
  label,
  value,
  bg,
  accent,
}: {
  label: string;
  value: string;
  bg: string;
  accent?: string;
}) {
  return (
    <View style={[styles.stat, { backgroundColor: bg }]}>
      <ThemedText style={[styles.statValue, accent && { color: accent }]}>
        {value}
      </ThemedText>
      <ThemedText style={styles.statLabel}>{label}</ThemedText>
    </View>
  );
}

function dotColor(name: string): string {
  if (name.includes('DidBecomeActive') || name.includes('WillEnterForeground')) {
    return '#27AE60';
  }
  if (name.includes('DidEnterBackground') || name.includes('WillResignActive')) {
    return '#F2994A';
  }
  if (name.includes('MemoryWarning') || name.includes('WillTerminate')) {
    return POCKETCASTS_RED;
  }
  if (name.includes('FinishLaunching')) {
    return '#0082C9';
  }
  return '#9B51E0';
}

const styles = StyleSheet.create({
  root: { flex: 1 },
  safe: { flex: 1 },
  header: {
    flexDirection: 'row',
    alignItems: 'center',
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.two,
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  headerTitle: { flex: 1, fontSize: 17, fontWeight: '600' },
  closeBtn: {
    paddingHorizontal: 14,
    paddingVertical: 6,
    borderRadius: 14,
  },
  closeText: { color: '#fff', fontWeight: '600', fontSize: 13 },
  scroll: { padding: Spacing.three, gap: Spacing.three },
  hero: { alignItems: 'center', paddingTop: Spacing.two, gap: 8 },
  icon: {
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconGlyph: { color: '#fff', fontSize: 26, fontWeight: '800' },
  title: { fontSize: 22, fontWeight: '700', textAlign: 'center' },
  subtitle: { fontSize: 13, textAlign: 'center', paddingHorizontal: 12 },
  code: { fontFamily: 'Menlo', fontSize: 11 },
  statsRow: { flexDirection: 'row', gap: Spacing.two, flexWrap: 'wrap' },
  stat: {
    flex: 1,
    minWidth: 70,
    paddingVertical: Spacing.two,
    paddingHorizontal: 8,
    borderRadius: 12,
    alignItems: 'center',
  },
  statValue: { fontSize: 22, fontWeight: '700' },
  statLabel: { fontSize: 11, marginTop: 2 },
  actionRow: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.two,
    borderRadius: 12,
    gap: Spacing.two,
  },
  actionTitle: { fontSize: 15, fontWeight: '600' },
  actionSubtitle: { fontSize: 12, marginTop: 2 },
  chevron: { fontSize: 24, fontWeight: '400' },
  section: {
    fontSize: 12,
    textTransform: 'uppercase',
    letterSpacing: 0.5,
    paddingHorizontal: 4,
  },
  list: { borderRadius: 12, overflow: 'hidden' },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    padding: Spacing.two,
    gap: Spacing.two,
  },
  eventDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
  },
  rowTitle: { fontSize: 14, fontWeight: '600', fontFamily: 'Menlo' },
  rowDomain: { fontSize: 11, marginTop: 2 },
  eventTime: { fontSize: 11, fontFamily: 'Menlo' },
});
