'use client';

import { useState } from 'react';

interface TimeSlot {
  id: string;
  time: string;
  satellite: string;
  station: string;
  duration: number;
  type: 'scheduled' | 'available' | 'maintenance' | 'completed';
}

const generateTimeSlots = (): TimeSlot[] => {
  const slots: TimeSlot[] = [];
  const stations = ['Station Alpha', 'Station Beta', 'Station Gamma'];
  const satellites = ['NOAA-19', 'ISS', 'GOES-16', 'Fengyun-3', 'Meteor-M2'];

  stations.forEach((station) => {
    for (let h = 0; h < 24; h += 2) {
      const time = `${String(h).padStart(2, '0')}:00`;
      if (Math.random() > 0.6) {
        slots.push({
          id: `${station}-${h}`,
          time,
          satellite: satellites[Math.floor(Math.random() * satellites.length)],
          station,
          duration: 30,
          type: Math.random() > 0.7 ? 'completed' : 'scheduled',
        });
      } else {
        slots.push({
          id: `avail-${station}-${h}`,
          time,
          satellite: '',
          station,
          duration: 30,
          type: 'available',
        });
      }
    }
  });

  slots[0].type = 'maintenance';
  return slots;
};

const typeColors: Record<string, string> = {
  scheduled: 'bg-primary-500/20 border-primary-500/40 text-primary-300',
  available: 'bg-green-500/10 border-green-500/20 text-green-400 border-dashed',
  maintenance: 'bg-yellow-500/10 border-yellow-500/20 text-yellow-400',
  completed: 'bg-surface-800 border-surface-700 text-surface-400',
};

const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const hours = Array.from({ length: 12 }, (_, i) => `${String(i * 2).padStart(2, '0')}:00`);

export default function SchedulePage() {
  const [currentDate, setCurrentDate] = useState('2024-01-15');
  const [view, setView] = useState<'day' | 'week' | 'month'>('week');
  const [slots] = useState(generateTimeSlots);

  const pendingConfirmations = slots.filter((s) => s.type === 'scheduled').length;

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-2xl font-bold text-white">Schedule</h1>
          <p className="text-surface-400 mt-1">
            Plan and manage ground station passes
          </p>
        </div>
        <div className="flex items-center gap-3">
          <div className="flex gap-1">
            {(['day', 'week', 'month'] as const).map((v) => (
              <button
                key={v}
                onClick={() => setView(v)}
                className={`px-3 py-1.5 text-sm rounded ${
                  view === v
                    ? 'bg-primary-600 text-white'
                    : 'text-surface-400 hover:text-surface-200'
                }`}
              >
                {v.charAt(0).toUpperCase() + v.slice(1)}
              </button>
            ))}
          </div>
          <button className="px-4 py-2 rounded-lg bg-gradient-to-r from-primary-600 to-primary-500 hover:from-primary-500 hover:to-primary-400 text-white font-medium text-sm transition-all">
            + New Pass
          </button>
        </div>
      </div>

      <div className="glass rounded-xl p-4">
        <div className="flex items-center justify-between mb-4">
          <button className="text-surface-400 hover:text-white transition-colors">
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M15.75 19.5L8.25 12l7.5-7.5" />
            </svg>
          </button>
          <div className="text-lg font-semibold text-white">
            Week of January 15, 2024
          </div>
          <button className="text-surface-400 hover:text-white transition-colors">
            <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" strokeWidth={1.5} stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" d="M8.25 4.5l7.5 7.5-7.5 7.5" />
            </svg>
          </button>
        </div>

        <div className="flex gap-2 text-xs text-surface-400 mb-4">
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-primary-500/20 border border-primary-500/40" />
            <span>Scheduled</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-green-500/10 border border-green-500/20 border-dashed" />
            <span>Available</span>
          </div>
          <div className="flex items-center gap-1">
            <div className="w-3 h-3 rounded bg-yellow-500/10 border border-yellow-500/20" />
            <span>Maintenance</span>
          </div>
        </div>

        <div className="overflow-x-auto">
          <div className="min-w-[800px]">
            <div className="grid grid-cols-[80px_repeat(3,1fr)] gap-1">
              <div className="text-xs text-surface-500 py-2" />
              {['Station Alpha', 'Station Beta', 'Station Gamma'].map((s) => (
                <div key={s} className="text-xs text-surface-400 font-medium py-2 text-center">
                  {s}
                </div>
              ))}

              {hours.map((hour) => (
                <div key={hour} className="contents">
                  <div className="text-xs text-surface-500 py-3 flex items-start">
                    {hour}
                  </div>
                  {[0, 1, 2].map((stationIdx) => {
                    const slot = slots.find(
                      (s) =>
                        s.time === hour &&
                        s.station === ['Station Alpha', 'Station Beta', 'Station Gamma'][stationIdx],
                    );
                    if (!slot) return <div key={stationIdx} className="h-12 bg-surface-900/50 rounded" />;
                    return (
                      <div
                        key={stationIdx}
                        className={`h-12 rounded p-1.5 border cursor-pointer transition-all hover:scale-[1.02] ${typeColors[slot.type]}`}
                      >
                        <div className="text-[10px] font-medium leading-tight truncate">
                          {slot.type === 'available'
                            ? 'Available'
                            : slot.type === 'maintenance'
                              ? '🔧 Maintenance'
                              : slot.satellite}
                        </div>
                        <div className="text-[10px] opacity-70">
                          {slot.duration}min
                        </div>
                      </div>
                    );
                  })}
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="glass rounded-xl p-4">
          <div className="text-2xl font-bold text-white">
            {pendingConfirmations}
          </div>
          <div className="text-sm text-surface-400">Pending Confirmations</div>
        </div>
        <div className="glass rounded-xl p-4">
          <div className="text-2xl font-bold text-white">
            {slots.filter((s) => s.type === 'completed').length}
          </div>
          <div className="text-sm text-surface-400">Completed Passes</div>
        </div>
        <div className="glass rounded-xl p-4">
          <div className="text-2xl font-bold text-white">
            {slots.filter((s) => s.type === 'available').length}
          </div>
          <div className="text-sm text-surface-400">Available Slots</div>
        </div>
      </div>
    </div>
  );
}
