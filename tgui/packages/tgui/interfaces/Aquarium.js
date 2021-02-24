import { useBackend } from '../backend';
import { Button, Dropdown, Flex, Knob, LabeledControls, Section } from '../components';
import { Window } from '../layouts';

export const Aquarium = (props, context) => {
  const { act, data } = useBackend(context);
  const {
    temperature,
    fluid_type,
    minTemperature,
    maxTemperature,
    fluidTypes,
    contents,
    allow_breeding,
  } = data;
  return (
    <Window
      width={500}
      height={400}
      resizable>
      <Window.Content>
        <Section title="Управление аквариумом">
          <LabeledControls>
            <LabeledControls.Item label="Температура">
              <Knob
                size={1.25}
                mb={1}
                value={temperature}
                unit="K"
                minValue={minTemperature}
                maxValue={maxTemperature}
                step={1}
                stepPixelSize={1}
                onDrag={(e, value) => act('temperature', {
                  temperature: value,
                })} />
            </LabeledControls.Item>
            <LabeledControls.Item label="Жидкость">
              <Flex direction="column" mb={1}>
                {fluidTypes.map(f => (
                  <Flex.Item key={f}>
                    <Button
                      fluid
                      content={f}
                      selected={fluid_type === f}
                      onClick={() => act('fluid', { fluid: f })} />
                  </Flex.Item>
                ))}
              </Flex>
            </LabeledControls.Item>
            <LabeledControls.Item label="Размножение рыбок">
              <Button
                content={allow_breeding ? "Выкл" : "Вкл"}
                selected={!allow_breeding}
                onClick={() => act('allow_breeding')} />
            </LabeledControls.Item>
          </LabeledControls>
        </Section>
        <Section title="Содержимое">
          {contents.map(movable => (
            <Button
              key={movable.ref}
              content={movable.name}
              onClick={() => act('remove', { ref: movable.ref })} />
          ))}
        </Section>
      </Window.Content>
    </Window>
  );
};
